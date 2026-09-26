// The shell's arithmetic. Two callers: the menu, where a query starting with
// "=" is an expression rather than a filter and its answer is the only row
// shown, and the calculator panel, which types into a bare expression.
//
// The evaluator is a small recursive-descent parser rather than the engine's
// own eval: the text comes from whatever was typed, and a grammar that can
// only ever produce a number has nothing else in the shell to reach.

var PREFIX = "="

var CONSTANTS = ({
  pi: Math.PI,
  "π": Math.PI,
  tau: Math.PI * 2,
  e: Math.E
})

var FUNCTIONS = ({
  abs: Math.abs,
  acos: Math.acos,
  asin: Math.asin,
  atan: Math.atan,
  cbrt: Math.cbrt,
  ceil: Math.ceil,
  cos: Math.cos,
  exp: Math.exp,
  floor: Math.floor,
  ln: Math.log,
  log: function(x) { return Math.log(x) / Math.LN10 },
  log2: function(x) { return Math.log(x) / Math.LN2 },
  log10: function(x) { return Math.log(x) / Math.LN10 },
  max: Math.max,
  min: Math.min,
  pow: Math.pow,
  round: Math.round,
  sin: Math.sin,
  sqrt: Math.sqrt,
  tan: Math.tan
})

function isQuery(text) {
  return String(text || "").trim().indexOf(PREFIX) === 0
}

function expressionOf(text) {
  var raw = String(text || "").trim()
  return isQuery(raw) ? raw.substring(PREFIX.length).trim() : ""
}

// A result, or null for anything that is not one yet: an empty "=", a
// half-typed "2+", a division by zero. The menu shows no row for null, so a
// query on its way to being valid never flashes an error.
function evaluate(text) {
  return evaluateExpression(expressionOf(text))
}

// The same, for callers that already hold a bare expression: the calculator
// panel types into one directly and has no "=" prefix to strip.
//
// `history` is the answers already worked out, newest first, which $0..$9 read
// from. A caller without one (the menu) leaves it out, and any $n there is an
// unknown rather than a number, so the query evaluates to nothing.
function evaluateExpression(text, history) {
  var expression = String(text || "").trim()
  if (!expression) return null

  var tokens = tokenize(expression)
  if (!tokens || tokens.length === 0) return null

  try {
    var state = { tokens: tokens, pos: 0, history: history || [] }
    var value = parseExpression(state)
    // Trailing tokens mean the parser stopped early, so the answer would be
    // for a prefix of what was typed.
    if (state.pos !== tokens.length) return null
    if (typeof value !== "number" || !isFinite(value)) return null
    return { expression: expression, value: value, text: format(value) }
  } catch (e) {
    return null
  }
}

// Binary floating point hands back 0.1 + 0.2 as 0.30000000000000004. Twelve
// significant digits is past anything typed into a menu and short of that noise.
function format(value) {
  if (Math.abs(value) < 1e21) return String(Number(value.toPrecision(12)))
  return String(value)
}

// ------------------------------------------------------------------- tokens

function isDigit(ch) {
  return ch >= "0" && ch <= "9"
}

function isNameChar(ch) {
  return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || ch === "π"
}

// The operators a keyboard and a copied expression both produce.
function operatorFor(ch) {
  if (ch === "×" || ch === "·") return "*"
  if (ch === "÷") return "/"
  if (ch === "−") return "-"
  return "+-*/%^(),".indexOf(ch) >= 0 ? ch : ""
}

function tokenize(text) {
  var s = String(text || "")
  var tokens = []
  var i = 0

  while (i < s.length) {
    var ch = s.charAt(i)

    if (ch === " " || ch === "\t") { i++; continue }

    if (isDigit(ch) || ch === ".") {
      var numberStart = i
      while (i < s.length && (isDigit(s.charAt(i)) || s.charAt(i) === ".")) i++
      // An exponent only counts when digits follow it, so "2e" stays a number
      // beside a name instead of swallowing the e.
      if (i < s.length && (s.charAt(i) === "e" || s.charAt(i) === "E")) {
        var afterSign = (s.charAt(i + 1) === "+" || s.charAt(i + 1) === "-") ? i + 2 : i + 1
        if (isDigit(s.charAt(afterSign))) {
          i = afterSign
          while (i < s.length && isDigit(s.charAt(i))) i++
        }
      }
      var value = Number(s.substring(numberStart, i))
      if (!isFinite(value)) return null
      tokens.push({ type: "number", value: value })
      continue
    }

    // $0 is the last answer, $1 the one before it, up to $9. One digit only:
    // past ten back, nobody is counting rows, and a multi-digit index would
    // make "$12" ambiguous between the twelfth answer and "$1 then 2".
    if (ch === "$") {
      var indexChar = s.charAt(i + 1)
      if (!isDigit(indexChar)) return null
      tokens.push({ type: "history", value: Number(indexChar) })
      i += 2
      continue
    }

    if (isNameChar(ch)) {
      var nameStart = i
      while (i < s.length && (isNameChar(s.charAt(i)) || isDigit(s.charAt(i)))) i++
      tokens.push({ type: "name", value: s.substring(nameStart, i).toLowerCase() })
      continue
    }

    var operator = operatorFor(ch)
    if (!operator) return null
    tokens.push({ type: "operator", value: operator })
    i++
  }

  return tokens
}

// ------------------------------------------------------------------- parser

function peek(state) {
  return state.pos < state.tokens.length ? state.tokens[state.pos] : null
}

function takeOperator(state, values) {
  var token = peek(state)
  if (!token || token.type !== "operator") return ""
  if (values.indexOf(token.value) < 0) return ""
  state.pos++
  return token.value
}

function expectOperator(state, value) {
  var token = peek(state)
  if (!token || token.type !== "operator" || token.value !== value) throw new Error("expected " + value)
  state.pos++
}

function parseExpression(state) {
  var value = parseTerm(state)
  var operator = takeOperator(state, ["+", "-"])

  while (operator) {
    var rhs = parseTerm(state)
    value = operator === "+" ? value + rhs : value - rhs
    operator = takeOperator(state, ["+", "-"])
  }

  return value
}

function parseTerm(state) {
  var value = parseUnary(state)
  var operator = takeOperator(state, ["*", "/", "%"])

  while (operator) {
    var rhs = parseUnary(state)
    if (operator === "*") value = value * rhs
    else if (operator === "/") value = value / rhs
    else value = value % rhs
    operator = takeOperator(state, ["*", "/", "%"])
  }

  return value
}

function parseUnary(state) {
  var sign = takeOperator(state, ["+", "-"])
  if (sign) {
    var value = parseUnary(state)
    return sign === "-" ? -value : value
  }
  return parsePower(state)
}

// Right-associative, and the exponent takes a sign of its own: 2^-1 is 0.5.
function parsePower(state) {
  var base = parsePrimary(state)
  if (takeOperator(state, ["^"])) return Math.pow(base, parseUnary(state))
  return base
}

function parsePrimary(state) {
  var token = peek(state)
  if (!token) throw new Error("unexpected end")

  if (token.type === "number") {
    state.pos++
    return token.value
  }

  if (token.type === "history") {
    var answer = state.history[token.value]
    if (typeof answer !== "number" || !isFinite(answer)) throw new Error("no $" + token.value)
    state.pos++
    return answer
  }

  if (token.type === "operator" && token.value === "(") {
    state.pos++
    var grouped = parseExpression(state)
    expectOperator(state, ")")
    return grouped
  }

  if (token.type === "name") {
    state.pos++
    if (CONSTANTS.hasOwnProperty(token.value)) return CONSTANTS[token.value]
    if (!FUNCTIONS.hasOwnProperty(token.value)) throw new Error("unknown name " + token.value)

    expectOperator(state, "(")
    var args = [parseExpression(state)]
    while (takeOperator(state, [","])) args.push(parseExpression(state))
    expectOperator(state, ")")
    return FUNCTIONS[token.value].apply(null, args)
  }

  throw new Error("unexpected token " + token.value)
}

if (typeof module !== "undefined") {
  module.exports = {
    isQuery: isQuery,
    expressionOf: expressionOf,
    evaluate: evaluate,
    evaluateExpression: evaluateExpression,
    format: format
  }
}
