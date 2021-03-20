import XCTest
@testable import Parseque

final class ParsequeTests: XCTestCase {
	
	func testCommaSeparatedListOfNumbersBetweenSquareBrackets() {
		let betweenSquareBrackets = between(
			leftParser: Parser.characterParser(matching: "["),
			content: Parser<Int>.intParser().seperated(by: Parser.characterParser(matching: ",")),
			rightParser: Parser.characterParser(matching: "]")
		)
		let parser = betweenSquareBrackets
		switch parser.run(input: "[1,2,3]") {
		case .value(let v, let remainder):
			XCTAssertEqual(v, [1,2,3])
			XCTAssertEqual(remainder, "")
		case .failure(let errorMessage):
			XCTFail(errorMessage)
		}
	}
	
	func testEither() {
		let betweenSquareBrackets = between(
			leftParser: Parser.characterParser(matching: "["),
			content: Parser<Int>.intParser().seperated(by: Parser.characterParser(matching: ",")),
			rightParser: Parser.characterParser(matching: "]")
		)
		let parser = either(firstParser: betweenSquareBrackets, secondParser: Parser.characterParser(matching: "a"))
		switch parser.run(input: "[1,2,3]") {
		case .value(let v, let remainder):
			switch v {
			case .left(let array):
				XCTAssertEqual(array, [1, 2, 3])
			case .right:
				XCTFail()
			}
			XCTAssertEqual(remainder, "")
		case .failure(let errorMessage):
			XCTFail(errorMessage)
		}
		
		switch parser.run(input: "a") {
		case .value(let v, let remainder):
			switch v {
			case .left:
				XCTFail()
			case .right(let character):
				XCTAssertEqual("a", character)
			}
			XCTAssertEqual(remainder, "")
		case .failure(let errorMessage):
			XCTFail(errorMessage)
		}
	}
	
	func testRecursiveCommaSeparatedListOfNumbersBetweenSquareBrackets() {

		enum ParseNode {
			case number(Int)
			case subnodes([ParseNode])
		}

		var makeArrayParser: () -> Parser<ParseNode> = { fatalError() }
		let nodeParser = lazilyProvided(by: {
			either(
				firstParser: Parser.intParser().map(ParseNode.number),
				secondParser: makeArrayParser()
			).map({ either -> ParseNode in
				switch either {
				case .left(let intNode): return intNode
				case .right(let arrayNode): return arrayNode
				}
			})
		})
		
		makeArrayParser = {
			between(
				leftParser: Parser.characterParser(matching: "["),
				content: nodeParser.seperated(by: Parser.characterParser(matching: ",")),
				rightParser: Parser.characterParser(matching: "]")
			)
			.map({ arrayOfNodes in
				ParseNode.subnodes(arrayOfNodes)
			})
		}
		
		let parser = nodeParser
		let result = parser.run(input: "[1,[2,3],4,5]")

		switch result {
		case .value(let node, _):
			switch node {
			case .number: XCTFail("Expected to have a top-level array, not numbers")
			case .subnodes(let subnodes):
				XCTAssertEqual(subnodes.count, 4)
			}
		case .failure(let message):
			XCTFail(message)
		}
	}

	func testASmallMathExpressionLanguage() {

		enum Operator: CaseIterable {
			case plus, minus, multiply, divide
			
			var stringValue: String {
				switch self {
				case .plus: return "+"
				case .minus: return "-"
				case .multiply: return "*"
				case .divide: return "/"
				}
			}
		}
		indirect enum ParseNode {
			case number(Int)
			case operation(op: Operator, left: ParseNode, right: ParseNode)
		}

		let numberParser = Parser.intParser().map(ParseNode.number)
		let operatorParser = choice(
			from: Operator
				.allCases
				.map(\.stringValue)
				.map({ Character.init($0) })
				.map(Parser.characterParser(matching:))
		).map({ character in
			Operator.allCases.first(where: { $0.stringValue == String(character) })!
		})
		
		var makeOperationParser: () -> Parser<ParseNode> = { fatalError() }
		let expressionParser = lazilyProvided(by: {
			either(
				firstParser: numberParser,
				secondParser: makeOperationParser()
			)
			.map({ either -> ParseNode in
				switch either {
				case .left(let intNode): return intNode
				case .right(let operationNode): return operationNode
				}
			})
		})
		
		makeOperationParser = {
			return between(
				leftParser: .characterParser(matching: "("),
				content: operatorParser
					.skipping1(otherParser: .whitespaceParser())
					.followed(by: expressionParser)
					.skipping1(otherParser: .whitespaceParser())
					.followed(by: expressionParser),
				rightParser: .characterParser(matching: ")")
			).map { (arg0) -> ParseNode in
				return ParseNode.operation(op: arg0.0.0, left: arg0.0.1, right: arg0.1)
			}
		}

		func evaluate(parseNode: ParseNode) -> Double {
			switch parseNode {
			case .number(let value): return Double(value)
			case let .operation(op, left, right):
				switch op {
				case .plus:
					return evaluate(parseNode: left) + evaluate(parseNode: right)
				case .minus:
					return evaluate(parseNode: left) - evaluate(parseNode: right)
				case .multiply:
					return evaluate(parseNode: left) * evaluate(parseNode: right)
				case .divide:
					return evaluate(parseNode: left) / evaluate(parseNode: right)
				}
			}
		}

		let parseResult = expressionParser.run(input: "(+ (* 10 2) (/ 20    4))")
		switch parseResult {
		case let .value(value, remainder):
			XCTAssertEqual(remainder, "")
			XCTAssertEqual(evaluate(parseNode: value), 25)
		case let .failure(message):
			XCTFail(message)
		}

	}
	
	func testASlightlyMoreComplicatedMathExpressionLanguage() {

		enum Operator: CaseIterable {
			case plus, minus, multiply, divide
			
			var stringValue: String {
				switch self {
				case .plus: return "+"
				case .minus: return "-"
				case .multiply: return "*"
				case .divide: return "/"
				}
			}
			
			var asFunction: (Double, Double) -> Double {
				switch self {
				case .plus: return (+)
				case .minus: return (-)
				case .multiply: return (*)
				case .divide: return (/)
				}
			}
		}
		indirect enum ParseNode {
			case number(Int)
			case operation(op: Operator, operands: [ParseNode])
		}

		let numberParser = Parser.intParser().map(ParseNode.number)
		let operatorParser = choice(
			from: Operator
				.allCases
				.map(\.stringValue)
				.map({ Character.init($0) })
				.map(Parser.characterParser(matching:))
		).map({ character in
			Operator.allCases.first(where: { $0.stringValue == String(character) })!
		})
		
		var makeOperationParser: () -> Parser<ParseNode> = { fatalError() }
		let expressionParser = lazilyProvided(by: {
			either(
				firstParser: numberParser,
				secondParser: makeOperationParser()
			)
			.map({ either -> ParseNode in
				switch either {
				case .left(let intNode): return intNode
				case .right(let operationNode): return operationNode
				}
			})
		})
		
		makeOperationParser = {
			return between(
				leftParser: .characterParser(matching: "("),
				content: operatorParser
					.skipping1(otherParser: .whitespaceParser())
					.followed(by: expressionParser.seperated(by: .whitespaceParser())),
				rightParser: .characterParser(matching: ")")
			).map { (arg0) -> ParseNode in
				return ParseNode.operation(op: arg0.0, operands: arg0.1)
			}
		}

		func evaluate(parseNode: ParseNode) -> Double {
			switch parseNode {
			case .number(let value): return Double(value)
			case let .operation(op, operands):
				guard operands.count > 1 else {
					print("Error when performing operation: \(op): didn't have enough operands.")
					return 0
				}
				let evaluated = operands.map(evaluate(parseNode:))
				return evaluated.dropFirst().reduce(evaluated.first!, op.asFunction)
			}
		}

		let parseResult = expressionParser.run(input: "(+ (* 10 2 2) (/ 20    4))")
		switch parseResult {
		case let .value(value, remainder):
			XCTAssertEqual(remainder, "")
			XCTAssertEqual(evaluate(parseNode: value), 45)
		case let .failure(message):
			XCTFail(message)
		}

	}
	
	func testCharacterMatches() {
		let parseA = Parser.characterParser(matching: "A")
		switch parseA.run(input: "ABC") {
		case .value(let v, let remainder):
			XCTAssertEqual(v, "A")
			XCTAssertEqual(remainder, "BC")
		case .failure:
			XCTFail()
		}
	}
	
	func testCharacterDoesNotMatch() {
		let parseA = Parser.characterParser(matching: "A")
		switch parseA.run(input: "ZBC") {
		case .value:
			XCTFail()
		case .failure:
			break
		}
	}
}
