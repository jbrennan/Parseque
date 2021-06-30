//
//  Created by Jason Brennan on 2021-03-11.
//

public enum ParseResult<Value> {
	case value(Value, remainder: String)
	case failure(String)
}

/// The main parser type, which takes an input string and returns a result.
///
/// The power of this type lies in utility functions which can be combined to create more sophisticated parsers.
public struct Parser<ResultType> {
	
	/// The parsing function. You can provide any kind of string parsing you'd like,
	/// but it's probably best to keep it simple and compose lots of simple parsers together.
	public let parse: (String) -> ParseResult<ResultType>
	
	/// Initialize the parser with a parse closure.
	///
	/// This is primarily used for writing new kinds of parsing tools.
	/// If you're just parsing something, you may instead want to use compose some of the static methods below, instead.
	public init(parse: @escaping (String) -> ParseResult<ResultType>) {
		self.parse = parse
	}
	
	/// Runs the parser. You probably only want to call this on your outermost parser to parse your whole string.
	public func run(input: String) -> ParseResult<ResultType> {
		return parse(input)
	}
}

public extension Parser where ResultType == Character {
	static func characterParser(matching characterToMatch: Character) -> Parser<Character> {
		return Parser(parse: {string in
			guard let firstCharacter = string.first else { return .failure("String is empty") }
			
			guard firstCharacter == characterToMatch else { return .failure("\(firstCharacter) from \(string) is not \(characterToMatch)") }
			
			return .value(characterToMatch, remainder: String(string.dropFirst()))
		})
	}
}

public extension Parser where ResultType == String {
	
	/// Parses leading sequential characters that are letters.
	static func lettersParser() -> Parser<String> {
		return stringParser(matching: \.isLetter)
	}

	/// Parses leading sequential characters that are whitespace (spaces, tabs, newlines, etc).
	static func whitespaceParser() -> Parser<String> {
		return stringParser(matching: \.isWhitespace)
	}
	
	static func stringParser(matchingUntil predicate: @escaping (Character) -> Bool) -> Parser<String> {
		return stringParser(matching: { predicate($0) == false })
	}
	
	static func stringParser(matchingUntil character: Character) -> Parser<String> {
		return stringParser(matchingUntil: { $0 == character })
	}

	/// Parses leading sequential characters matching the given `predicate`.
	static func stringParser(matching predicate: @escaping (Character) -> Bool) -> Parser<String> {
		return Parser(parse: { string in
			guard string.isEmpty == false else {
				return .failure("String is empty")
			}
			
			var foundResult = ""
			let remainder = string.drop(while: {
				if predicate($0) {
					foundResult.append($0)
					return true
				}
				return false
			})
			guard foundResult.isEmpty == false else {
				return .failure("Didn't find any leading characters that matched the given predicate.")
			}
			print("String parser found result: `\(foundResult)` Remainder: `\(remainder)`")
			return .value(foundResult, remainder: String(remainder))
		})
	}
	
	// TODO: write some tests for this, idk if it works great
	static func stringParser(matching text: String) -> Parser<String> {
		return Parser(parse: { string in
			guard string.isEmpty == false else { return .failure("String is empty") }
			guard string.hasPrefix(text) else { return .failure("String Parser did not begin with text: `\(text)`") }
			
			return .value(text, remainder: String(string.dropFirst(text.count)))
		})
	}
	
	// TODO: unit test this.
	/// Matches until the first instance of the given `text`, and includes that `text` in the remainder.
	static func stringParser(matchingUntilFirstInstanceOf text: String) -> Parser<String> {
		return Parser(parse: { string in
			guard string.isEmpty == false else { return .failure("String is empty") }
			guard let firstRange = string.range(of: text) else {
				return .failure("String parser could not find an occurrance of text: `\(text)`")
			}
			
//			return .value(String(string[..<firstRange.lowerBound]), remainder: String(string[firstRange.upperBound...]))
			return .value(String(string[..<firstRange.lowerBound]), remainder: String(string[firstRange.lowerBound...]))
		})
	}
	
	// TODO: unit test this too
	// I don't think this is really what I want.
	// when parsing a string like `blah blah end` and matching with a predicate like `string.hasSuffix("end") == false`
	// it correctly stops parsing when it gets to the `end` part, but because it's already consumed the `e,n`
	// that gets added to the parsed string, which is not what I want.
	//
	// I think I really just want something like `stringParser(matchingUntil text: String)`, akin to the above parser
	static func stringParser(matchingAccumulatedText predicate: @escaping (String) -> Bool) -> Parser<String> {
		return Parser(parse: { string in
			guard string.isEmpty == false else { return .failure("String is empty") }
			
			var accumulatedText = ""
			let remainder = string.drop(while: {
				if predicate(accumulatedText.appending(String($0))) {
					accumulatedText.append($0)
					return true
				}
				return false
			})
			
			guard accumulatedText.isEmpty == false else {
				return .failure("String parser did not find a matching string.")
			}
			
			return .value(accumulatedText, remainder: String(remainder))
		})
	}
}

public extension Parser {
	
	/// A parser that conditionally passes, based on the result of the given predicate.
	///
	/// This is conceptually similar to `filter()`, but on the result value.
	func matching(where predicate: @escaping (ResultType) -> Bool) -> Parser<ResultType> {
		return Parser<ResultType>(parse: { string in
			switch self.parse(string) {
			case let .value(value, remainder):
				if predicate(value) {
					return .value(value, remainder: remainder)
				}
				return .failure("Value \(value) did not pass `matching(where:)`")
				
			case .failure(let message):
				return .failure(message)
			}
		})
	}
	
	/// Allows you to debug values at any point in a parser chain.
	///
	/// Calling this method will insert a print statement when it's evaluated, with its current value.
	func debug() -> Parser<ResultType> {
		return Parser<ResultType>(parse: { string in
			switch self.parse(string) {
			case let .value(result, remainder):
				print("*** Value: `\(result)`. Remainder: `\(remainder)`")
				return .value(result, remainder: remainder)
				
			case .failure(let message):
				print("*** Failure: \(message)")
				return .failure(message)
			}
		})
	}
}

public extension Parser where ResultType == Int {
	
	/// Parses leading sequential characters that are whole numbers.
	static func intParser() -> Parser<Int> {
		return Parser<String>.stringParser(matching: \.isWholeNumber).map({ Int($0)! })
	}
}

public extension Parser {
	
	/// Maps the result value type to a new type.
	func map<NextType>(_ transformer: @escaping (ResultType) -> NextType) -> Parser<NextType> {
		Parser<NextType>(parse: { string in
			switch self.parse(string) {
			case let .value(value, remainder):
				return .value(transformer(value), remainder: remainder)
			case .failure(let error):
				return .failure(error)
			}
		})
	}

	/// Maps the error message to a new message. You can use this to give more relevant error messages.
	///
	/// In the future, the error reporting should be improved so that parsers can give more structured feedback. For now, we'll rely on string replacements.
	func mapError(_ transformer: @escaping (String) -> String) -> Parser<ResultType> {
		Parser<ResultType>(parse: { string in
			switch self.parse(string) {
			case let .value(value, remainder):
				return .value(value, remainder: remainder)
			case .failure(let error):
				return .failure(transformer(error))
			}
		})
	}
	
	/// Ignores the input and just maps to the provided value.
	///
	/// Useful when transforming a parsed value to an enum case that doesn't have associated values.
	func mapConstant<ConstantType>(_ constant: ConstantType) -> Parser<ConstantType> {
		map { _ in constant }
	}
	
	/// Returns a tuple of the receiver parser type (self) and the following parser type.
	func followed<NextType>(by otherParser: Parser<NextType>) -> Parser<(ResultType, NextType)> {
		// return a new parser that composes ourselves + the "other" parser
		return Parser<(ResultType, NextType)>(parse: { string in
			// parse the string on `self` first...
			switch self.parse(string) {
			
			// if it succeeded, then parse the `otherParser`...
			case .value(let value, let remainder):
				switch otherParser.parse(remainder) {
				case let .value(innerValue, innerRemainder):
					// otherParser succeeded! return the values
					return .value((value, innerValue), remainder: innerRemainder)
				case .failure(let message):
					// otherParser failed, ah well
					return .failure(message)
				}
				
			case .failure(let message):
				// self failed to parse
				return .failure(message)
			}
		})
	}

	/// Similar to `followed(by:)`, but ignores the result of the parser that follows.
	/// You could use this to skip whitespace after some other parser.
	func skipping1<SkippedType>(otherParser: Parser<SkippedType>) -> Parser<ResultType> {
		return followed(by: otherParser).map({ $0.0 })
	}
	
	/// Skips 0-or-more whitespace characters.
	func skippingWhitespace() -> Parser<ResultType> {
		skipping1(otherParser: zeroOrMore(of: .whitespaceParser()))
	}
	
	/// Skips 1-or-more whitespace characters.
	func skipping1OrMoreWhitespace() -> Parser<ResultType> {
		skipping1(otherParser: .whitespaceParser())
			.skippingWhitespace()
	}
	
	// `.or()` should probably just have the same type as the receiver
//	func or<NextType>(otherParser: Parser<NextType>) -> Parser<(ResultType, NextType)> {
//		// return a new parser that composes ourselves + the "other" parser
////		return Parser<(ResultType, NextType)>(parse: { string in
////			// parse the string on `self` first...
////			switch self.parse(string) {
////
////			// if it succeeded, then parse the `otherParser`...
////			case .value(let value, let remainder):
////				return .value(<#T##(ResultType, NextType)#>, remainder: <#T##String#>)
////				case .failure(let message):
////					// otherParser failed, ah well
////					return .failure(message)
////				}
////
////			case .failure(let message):
////				// self failed to parse
////				return .failure(message)
////			}
////		})
//	}
	
	/// Returns an array containing 0-or-more of the receiver's (self) result type, which were found by ignoring values parsed by the `separatorParser`.
	/// You might use this to parse a comma-separated list of values, for example.
	func seperated<SeparatorType>(by separatorParser: Parser<SeparatorType>) -> Parser<[ResultType]> {
		return Parser<[ResultType]>(parse: { string in
			var components = [ResultType]()
			var remainingString = string
			var keepLooping = true
			
			print("--- separated: begin for string: `\(remainingString)`")
			while keepLooping {
				switch self.parse(remainingString) {
				case let .value(value, remainder):
					components.append(value)
					remainingString = remainder
				case .failure:
					// if I just used `break` here, that would only break out of the switch
					// and I don't want to use labels either; a Bool is more explicit.
					keepLooping = false
					
					// todo: do I want a `continue` here? Or do I want to try to parse the separator? I think I want to bail...
					continue
				}
				
				// then, try to parse the separator
				switch separatorParser.parse(remainingString) {
				case let .value(_, remainder):
					remainingString = remainder
				case .failure:
					keepLooping = false
				}
			}
			print("--- separated: END. Found: `\(components)`. remaining: `\(remainingString)`")
			return .value(components, remainder: remainingString)
		})
	}
	
	/// Returns an array containing 1-or-more of the receiver's result type, which were found by ignoring values parsed by the `separatorParser`.
	func seperated<SeparatorType>(by1 separatorParser: Parser<SeparatorType>) -> Parser<[ResultType]> {
		return Parser<[ResultType]>(parse: { string in
			var components = [ResultType]()
			var remainingString = string
			var keepLooping = true
			
			while keepLooping {
				switch self.parse(remainingString) {
				case let .value(value, remainder):
					components.append(value)
					remainingString = remainder
				case .failure:
					// if I just used `break` here, that would only break out of the switch
					// and I don't want to use labels either; a Bool is more explicit.
					keepLooping = false
					continue
				// maybe I should exit out of the loop immediately? or do I want to do the switch below??
				}
				
				// then, try to parse the separator
				switch separatorParser.parse(remainingString) {
				case let .value(_, remainder):
					remainingString = remainder
					print("Got sep value")
				case .failure:
					keepLooping = false
				}
			}
			
			guard components.isEmpty == false else {
				return .failure("Expected to have at least 1 result in `separated(by1:)` parser.")
			}
			
			return .value(components, remainder: remainingString)
		})
	}
}

/// Returns a parser for the content in between the left and right bounding parsers.
/// You might use this for parsing content between ( and ) for example.
public func between<Surrounding, ContentType>(leftParser: Parser<Surrounding>, content: Parser<ContentType>, rightParser: Parser<Surrounding>) -> Parser<ContentType> {
	return leftParser.followed(by: content).followed(by: rightParser).map({
		// drill in to return the ContentType
		$0.0.1
	})
}

/// Returns a parser for the content in between the left and right characters.
/// You might use this for parsing content between ( and ) for example.
public func between<ContentType>(leftCharacter: Character, content: Parser<ContentType>, rightCharacter: Character) -> Parser<ContentType> {
	return Parser.characterParser(matching: leftCharacter)
		.followed(by: content)
		.followed(by: .characterParser(matching: rightCharacter))
		.map({
			// drill in to return the ContentType
			$0.0.1
		})
}

/// Similar to `between()` except this function extracts the left and right side and ignores what's in between.
public func split<LeftType, SeparatorType, RightType>(left: Parser<LeftType>, separator: Parser<SeparatorType>, right: Parser<RightType>) -> Parser<(LeftType, RightType)> {
	return left
		.followed(by: separator)
		.followed(by: right)
		.map {
			return ($0.0.0, $0.1)
		}
}

public func zeroOrMore<ResultType>(of parser: Parser<ResultType>) -> Parser<[ResultType]> {
	return Parser<[ResultType]>(parse: { string in
		var components = [ResultType]()
		var remainingString = string
		var keepLooping = true
		
		while keepLooping {
			switch parser.parse(remainingString) {
			case let .value(value, remainder):
				components.append(value)
				remainingString = remainder
			case .failure:
				// if I just used `break` here, that would only break out of the switch
				// and I don't want to use labels either; a Bool is more explicit.
				keepLooping = false
			}
		}
		
		return .value(components, remainder: remainingString)
	})
}

public enum Either<Left, Right> {
	case left(Left)
	case right(Right)
}

/// Returns one or the other of the two parsers provided, or an error value if neither succeeded.
public func either<FirstType, SecondType>(firstParser: Parser<FirstType>, secondParser: Parser<SecondType>) -> Parser<Either<FirstType, SecondType>> {
	return Parser(parse: { string in
		switch firstParser.parse(string) {
		case let .value(firstValue, remainder):
			return .value(.left(firstValue), remainder: remainder)
		case let .failure(firstError):
			switch secondParser.parse(string) {
			case let .value(secondValue, remainder):
				return .value(.right(secondValue), remainder: remainder)
			case .failure(let secondError):
				return .failure("\(firstError) AND \(secondError)")
			}
		}
	})
}

/// Returns the first of the given `parsers` that matches.
public func choice<ResultType>(from parsers: [Parser<ResultType>]) -> Parser<ResultType> {
	return Parser(parse: { string in
		for parser in parsers {
			switch parser.parse(string) {
			case let .value(value, remainder):
				return .value(value, remainder: remainder)
			case .failure:
				break
			}
		}
		
		return .failure("choice: No parsers matched.")
	})
}

/// This parser lazily evaluates its parser `provider` function.
/// This is useful when you need to recursively call a parser.
///
/// To be honest, it's kind of a hack.
public func lazilyProvided<ResultType>(by provider: @escaping () -> Parser<ResultType>) -> Parser<ResultType> {
	return Parser(parse: { string in
		provider().parse(string)
	})
}

public extension Bool {
	
	/// Returns if the receiver is `false`. Can be used in keypaths.
	var isFalse: Bool { self == false }
}
