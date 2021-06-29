//
//  ParserProviding.swift
//  
//
//  Created by Jason Brennan on 2021-06-29.
//

import Foundation

/// Conforming types statically return parsers capable of parsing the type.
public protocol ParserProviding {
	
	/// Returns a parser configured to parse out the designated type.
	static func parser() -> Parser<Self>
}
