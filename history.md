
Parseque History
================

1st Edition
---------


The 1st Edition of Parseque started as an experiment in learning what parser combinators were all about. I loosely followed some examples found online, in particular Soroush Khanlou's blog post about them, and some youtube videos for PC libraries in other languages. It was mostly just me trying to blindly grasp my way through working with them, how they combined, etc.

The library turned into a small, but nice little toolbelt, as I used it on a few test projects. I loved the way the parts combined to make better abstractions as I went, it felt like the tool was continuously leveling up!

Some things I liked about it:

1. Pretty easy to compose things.
2. Well suited to TDD, in fact most of my projects were intentionally made TDD because it's so input-output friendly.
3. Once I added a `ParserProviding` protocol, the parsers sorrrrrta started writing themselves. To a degree. The overall structure, at least.

However, there were also some pain points I encountered as I went:

1. Debugging is very challenging. It's perhaps the worst part about working with parser combinators, especially for making a programming language with them.
	
	Because you're essentially working with a bunch of functions, declared at compile time, it becomes very hard to track down what's what at runtime. A parser fails, but why? What goes wrong? What decides there isn't a match, and why? What would be better? Where do things go wrong? etc. It's nearly impossible to tell, and I found myself "playing computer" in my head while working with it.
	
	I think working more directly with types (instead of functions) would be fruitful here, as a starting point.

2. Whitespace! Most programming languages are quite whitespace flexible, but parser combinators are extremely literal in what they accept. Hard to sprinkle in whitespace skipping without breaking other things too. Ouch!

3. Structure! When should a parser be an instance method or a static method? or a free function? Kinda hard to tell, and sometimes you want something that works both ways.

Where to go from here?

Imagining the 2nd Edition
-------------------

I'd like to try a second edition of the library, one to help address some of the drawbacks. Primarily, I want something that is easier to debug, in 2 ways:

1. Easier to see exactly where we are in the debug flow (which map is this???), especially in Xcode's debugging tools. This is essential.

2. Easier to render debug pictures and visualizations of. I need to be able to output a picture of the parser + parsing run, to be able to see the data that's flowing through the system.

3. Nice to have: better error reporting for programming language style feedback (realtime error checking as you type). This one's not strictly necessary, as I don't need it yet, but I think I'll need it as my language gets more advanced, and I'd like to design the 2nd edition with this in mind.

I think I'm going to try something akin to SwiftUI: a protocol, with small, mostly struct, conforming types, and then some "modifiers" as needed. I think the types already match up with my earlier protocol attempt, but hopefully will solidify things more. I think they'll make debug tracing a little easier too.

Plus, if I have a graph of types, it should be easy to make those types visualizable, possibly even by making them conform to `SwiftUI.View` (but I'm not sure I'll go this way).
