// Command networker-live serves networker's live flows without keeping any
// history: no database is opened and nothing is written to disk.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"math"
	"net/http"
	"os"
	"os/signal"
	"sync/atomic"
	"syscall"
	"time"

	"golang.org/x/sys/unix"

	"github.com/tagptroll1/networker/internal/api"
	"github.com/tagptroll1/networker/internal/capture"
	"github.com/tagptroll1/networker/internal/geo"
	"github.com/tagptroll1/networker/internal/history"
	"github.com/tagptroll1/networker/internal/names"
	"github.com/tagptroll1/networker/internal/tracker"
)

// discard satisfies the tracker's history hook. IDs must stay unique since
// clients key live flows by them.
type discard struct{ next atomic.Int64 }

func (d *discard) Add(context.Context, history.Connection) (int64, error) { return d.next.Add(1), nil }
func (d *discard) Update(context.Context, history.Connection) error       { return nil }

type flow struct {
	tracker.Flow
	Location *geo.Location `json:"location"`
	Domain   string        `json:"domain,omitempty"`
}

func main() {
	listen := flag.String("listen", "127.0.0.1:8766", "loopback HTTP address")
	city := flag.String("city-db", "", "path to a City MMDB (GeoLite2 or DB-IP)")
	asn := flag.String("asn-db", "", "optional path to an ASN MMDB")
	lat := flag.Float64("origin-lat", math.NaN(), "approximate map origin latitude")
	lon := flag.Float64("origin-lon", math.NaN(), "approximate map origin longitude")
	flag.Parse()
	if !api.Loopback(*listen) {
		log.Fatal("-listen must be numeric loopback address and port")
	}
	if *city == "" {
		log.Fatal("-city-db is required")
	}
	if math.IsNaN(*lat) != math.IsNaN(*lon) {
		log.Fatal("set both origin coordinates or neither")
	}
	var origin *api.Origin
	if !math.IsNaN(*lat) {
		if *lat < -90 || *lat > 90 || *lon < -180 || *lon > 180 {
			log.Fatal("invalid origin coordinates")
		}
		origin = &api.Origin{Latitude: *lat, Longitude: *lon}
	}

	locations, err := geo.Open(*city, *asn)
	if err != nil {
		log.Fatal(err)
	}
	defer locations.Close()
	collector, err := capture.Open()
	if err != nil {
		log.Fatal(err)
	}
	defer collector.Close()
	cache := names.New()
	track := tracker.New(collector, &discard{})
	// HTTP keeps answering while polling fails, so clients need these to tell
	// fresh data from aging data.
	var lastOK atomic.Int64 // unix ms
	var lastErr, dnsErr atomic.Pointer[string]

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	// DNS answers only name live flows; questions are dropped.
	go func() {
		ignore := func(context.Context, capture.DNSQuery, time.Time) error { return nil }
		if err := collector.ReadDNS(ctx, ignore, cache.Remember); err != nil && ctx.Err() == nil {
			log.Printf("capture DNS: %v", err)
			msg := err.Error()
			dnsErr.Store(&msg)
		}
	}()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/config", func(w http.ResponseWriter, r *http.Request) {
		respond(w, struct {
			Origin *api.Origin `json:"origin"`
		}{origin})
	})
	mux.HandleFunc("GET /api/flows", func(w http.ResponseWriter, r *http.Request) {
		live := track.Live(time.Now())
		result := make([]flow, 0, len(live))
		for _, item := range live {
			domain := ""
			if item.Direction == "outbound" {
				domain = cache.Lookup(item.Remote.Addr())
			}
			result = append(result, flow{item, locations.Find(item.Remote.Addr()), domain})
		}
		respond(w, result)
	})
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, r *http.Request) {
		respond(w, struct {
			Now        int64   `json:"now"`
			LastPollOK int64   `json:"last_poll_ok"`
			LastError  *string `json:"last_error"`
			DNSError   *string `json:"dns_error"`
		}{time.Now().UnixMilli(), lastOK.Load(), lastErr.Load(), dnsErr.Load()})
	})
	server := &http.Server{Addr: *listen, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	errs := make(chan error, 1)
	go func() { errs <- server.ListenAndServe() }()
	log.Printf("networker-live listening at http://%s", *listen)

	// A persistent failure would otherwise log every second.
	var logged string
	var loggedAt time.Time
	failed := func(now time.Time, err error) {
		msg := err.Error()
		lastErr.Store(&msg)
		if msg != logged || now.Sub(loggedAt) >= time.Minute {
			log.Printf("poll traffic: %s", msg)
			logged, loggedAt = msg, now
		}
	}

	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for {
		select {
		case err := <-errs:
			log.Fatal(err)
		case <-ctx.Done():
			shutdown, done := context.WithTimeout(context.Background(), 3*time.Second)
			defer done()
			if err := server.Shutdown(shutdown); err != nil {
				log.Print(err)
			}
			return
		case now := <-ticker.C:
			var ts unix.Timespec
			if err := unix.ClockGettime(unix.CLOCK_MONOTONIC, &ts); err != nil {
				failed(now, err)
				continue
			}
			if err := track.Poll(ctx, now, uint64(ts.Nano())); err != nil {
				failed(now, err)
				continue
			}
			lastOK.Store(now.UnixMilli())
			lastErr.Store(nil)
			if logged != "" {
				log.Print("poll traffic recovered")
				logged = ""
			}
		}
	}
}

func respond(w http.ResponseWriter, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(value)
}
