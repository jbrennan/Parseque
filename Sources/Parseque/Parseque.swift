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

	/// Parses leading sequential characters matching the given `predicate`.
	static func stringParser(matching predicate: @escaping (Character) -> Bool) -> Parser<String> {
		return Parser(parse: { string in
			guard string.isEmpty == false else { return .failure("String is empty") }
			
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
			
			return .value(foundResult, remainder: String(remainder))
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
	
	/// Returns an array of the receiver's (self) result type, which were found by ignoring values parsed by the `separatorParser`.
	/// You might use this to parse a comma-separated list of values, for example.
	func seperated<SeparatorType>(by separatorParser: Parser<SeparatorType>) -> Parser<[ResultType]> {
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
				}
				
				// then, try to parse the separator
				switch separatorParser.parse(remainingString) {
				case let .value(_, remainder):
					remainingString = remainder
				case .failure:
					keepLooping = false
				}
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
			if case let .value(value, remainder) = parser.parse(string) {
				return .value(value, remainder: remainder)
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
