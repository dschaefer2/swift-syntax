//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if swift(>=6.0)
import SwiftBasicFormat
public import SwiftDiagnostics
@_spi(FixItApplier) import SwiftIDEUtils
import SwiftParser
import SwiftParserDiagnostics
public import SwiftSyntax
public import SwiftSyntaxMacroExpansion
private import SwiftSyntaxMacros
private import _SwiftSyntaxTestSupportFrameworkAgnostic
#else
import SwiftBasicFormat
import SwiftDiagnostics
@_spi(FixItApplier) import SwiftIDEUtils
import SwiftParser
import SwiftParserDiagnostics
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import _SwiftSyntaxTestSupportFrameworkAgnostic
#endif

/// Defines the location at which the a test failure should be anchored. This is typically the location where the
/// assertion function is called.
public struct TestFailureLocation {
  public let fileID: StaticString
  public let filePath: StaticString
  public let line: UInt
  public let column: UInt

  public init(
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) {
    self.fileID = fileID
    self.filePath = filePath
    self.line = line
    self.column = column
  }

  fileprivate init(underlying: _SwiftSyntaxTestSupportFrameworkAgnostic.TestFailureLocation) {
    self.init(
      fileID: underlying.fileID,
      filePath: underlying.filePath,
      line: underlying.line,
      column: underlying.column
    )
  }

  /// This type is intentionally different to `_SwiftSyntaxTestSupportFrameworkAgnostic.TestFailureLocation` so we can
  /// import `_SwiftSyntaxTestSupportFrameworkAgnostic` privately and don't expose its internal types.
  fileprivate var underlying: _SwiftSyntaxTestSupportFrameworkAgnostic.TestFailureLocation {
    _SwiftSyntaxTestSupportFrameworkAgnostic.TestFailureLocation(
      fileID: self.fileID,
      filePath: self.filePath,
      line: self.line,
      column: self.column
    )
  }
}

/// Defines the details of a test failure, consisting of a message and the location at which the test failure should be
/// shown.
public struct TestFailureSpec {
  public let message: String
  public let location: TestFailureLocation

  public init(message: String, location: TestFailureLocation) {
    self.message = message
    self.location = location
  }

  fileprivate init(underlying: _SwiftSyntaxTestSupportFrameworkAgnostic.TestFailureSpec) {
    self.init(
      message: underlying.message,
      location: TestFailureLocation(underlying: underlying.location)
    )
  }
}

// MARK: - Note

/// Describes a diagnostic note that tests expect to be created by a macro expansion.
public struct NoteSpec {
  /// The expected message of the note
  public let message: String

  /// The line to which the note is expected to point
  public let line: Int

  /// The column to which the note is expected to point
  public let column: Int

  /// The file and line at which this ``NoteSpec`` was created, so that assertion failures can be reported at its location.
  internal let failureLocation: TestFailureLocation

  /// Creates a new ``NoteSpec`` that describes a note tests are expecting to be generated by a macro expansion.
  ///
  /// - Parameters:
  ///   - message: The expected message of the note
  ///   - line: The line to which the note is expected to point
  ///   - column: The column to which the note is expected to point
  ///   - originatorFile: The file at which this ``NoteSpec`` was created, so that assertion failures can be reported at its location.
  ///   - originatorLine: The line at which this ``NoteSpec`` was created, so that assertion failures can be reported at its location.
  public init(
    message: String,
    line: Int,
    column: Int,
    originatorFileID: StaticString = #fileID,
    originatorFile: StaticString = #filePath,
    originatorLine: UInt = #line,
    originatorColumn: UInt = #column
  ) {
    self.message = message
    self.line = line
    self.column = column
    self.failureLocation = TestFailureLocation(
      fileID: originatorFileID,
      filePath: originatorFile,
      line: originatorLine,
      column: originatorColumn
    )
  }
}

func assertNote(
  _ note: Note,
  in expansionContext: BasicMacroExpansionContext,
  expected spec: NoteSpec,
  failureHandler: (TestFailureSpec) -> Void
) {
  assertStringsEqualWithDiff(
    note.message,
    spec.message,
    "message of note does not match",
    location: spec.failureLocation.underlying,
    failureHandler: { failureHandler(TestFailureSpec(underlying: $0)) }
  )
  let location = expansionContext.location(for: note.position, anchoredAt: note.node, fileName: "")
  if location.line != spec.line {
    failureHandler(
      TestFailureSpec(
        message: "line of note \(location.line) does not match expected line \(spec.line)",
        location: spec.failureLocation
      )
    )
  }
  if location.column != spec.column {
    failureHandler(
      TestFailureSpec(
        message: "column of note \(location.column) does not match expected column \(spec.column)",
        location: spec.failureLocation
      )
    )
  }
}

// MARK: - Fix-It

/// Describes a Fix-It that tests expect to be created by a macro expansion.
///
/// Currently, it only compares the message of the Fix-It. In the future, it might
/// also compare the expected changes that should be performed by the Fix-It.
public struct FixItSpec {
  /// The expected message of the Fix-It
  public let message: String

  /// The file and line at which this ``FixItSpec`` was created, so that assertion failures can be reported at its location.
  internal let failureLocation: TestFailureLocation

  /// Creates a new ``FixItSpec`` that describes a Fix-It tests are expecting to be generated by a macro expansion.
  ///
  /// - Parameters:
  ///   - message: The expected message of the note
  ///   - originatorFile: The file at which this ``NoteSpec`` was created, so that assertion failures can be reported at its location.
  ///   - originatorLine: The line at which this ``NoteSpec`` was created, so that assertion failures can be reported at its location.
  public init(
    message: String,
    originatorFileID: StaticString = #fileID,
    originatorFile: StaticString = #filePath,
    originatorLine: UInt = #line,
    originatorColumn: UInt = #column
  ) {
    self.message = message
    self.failureLocation = TestFailureLocation(
      fileID: originatorFileID,
      filePath: originatorFile,
      line: originatorLine,
      column: originatorColumn
    )
  }
}

func assertFixIt(
  _ fixIt: FixIt,
  expected spec: FixItSpec,
  failureHandler: (TestFailureSpec) -> Void
) {
  assertStringsEqualWithDiff(
    fixIt.message.message,
    spec.message,
    "message of Fix-It does not match",
    location: spec.failureLocation.underlying,
    failureHandler: { failureHandler(TestFailureSpec(underlying: $0)) }
  )
}

// MARK: - Diagnostic

/// Describes a diagnostic that tests expect to be created by a macro expansion.
public struct DiagnosticSpec {
  /// If not `nil`, the ID, which the diagnostic is expected to have.
  public let id: MessageID?

  /// The expected message of the diagnostic
  public let message: String

  /// The line to which the diagnostic is expected to point
  public let line: Int

  /// The column to which the diagnostic is expected to point
  public let column: Int

  /// The expected severity of the diagnostic
  public let severity: DiagnosticSeverity

  /// If not `nil`, the text fragments the diagnostic is expected to highlight
  public let highlights: [String]?

  /// The notes that are expected to be attached to the diagnostic
  public let notes: [NoteSpec]

  /// The messages of the Fix-Its the diagnostic is expected to produce
  public let fixIts: [FixItSpec]

  /// The file and line at which this ``NoteSpec`` was created, so that assertion failures can be reported at its location.
  internal let failureLocation: TestFailureLocation

  /// Creates a new ``DiagnosticSpec`` that describes a diagnostic tests are expecting to be generated by a macro expansion.
  ///
  /// - Parameters:
  ///   - id: If not `nil`, the ID, which the diagnostic is expected to have.
  ///   - message: The expected message of the diagnostic
  ///   - line: The line to which the diagnostic is expected to point
  ///   - column: The column to which the diagnostic is expected to point
  ///   - severity: The expected severity of the diagnostic
  ///   - highlights: If not empty, the text fragments the diagnostic is expected to highlight
  ///   - notes: The notes that are expected to be attached to the diagnostic
  ///   - fixIts: The messages of the Fix-Its the diagnostic is expected to produce
  ///   - originatorFile: The file at which this ``NoteSpec`` was created, so that assertion failures can be reported at its location.
  ///   - originatorLine: The line at which this ``NoteSpec`` was created, so that assertion failures can be reported at its location.
  public init(
    id: MessageID? = nil,
    message: String,
    line: Int,
    column: Int,
    severity: DiagnosticSeverity = .error,
    highlights: [String]? = nil,
    notes: [NoteSpec] = [],
    fixIts: [FixItSpec] = [],
    originatorFileID: StaticString = #fileID,
    originatorFile: StaticString = #filePath,
    originatorLine: UInt = #line,
    originatorColumn: UInt = #column
  ) {
    self.id = id
    self.message = message
    self.line = line
    self.column = column
    self.severity = severity
    self.highlights = highlights
    self.notes = notes
    self.fixIts = fixIts
    self.failureLocation = TestFailureLocation(
      fileID: originatorFileID,
      filePath: originatorFile,
      line: originatorLine,
      column: originatorColumn
    )
  }
}

extension DiagnosticSpec {
  @available(*, deprecated, message: "Use highlights instead")
  public var highlight: String? {
    guard let highlights else {
      return nil
    }
    return highlights.joined(separator: " ")
  }

  // swift-format-ignore
  @available(*, deprecated, message: "Use init(id:message:line:column:severity:highlights:notes:fixIts:originatorFile:originatorLine:) instead")
  @_disfavoredOverload
  public init(
    id: MessageID? = nil,
    message: String,
    line: Int,
    column: Int,
    severity: DiagnosticSeverity = .error,
    highlight: String? = nil,
    notes: [NoteSpec] = [],
    fixIts: [FixItSpec] = [],
    originatorFile: StaticString = #filePath,
    originatorLine: UInt = #line
  ) {
    self.init(
      id: id,
      message: message,
      line: line,
      column: column,
      severity: severity,
      highlights: highlight.map { [$0] },
      notes: notes,
      fixIts: fixIts
    )
  }
}

func assertDiagnostic(
  _ diag: Diagnostic,
  in expansionContext: BasicMacroExpansionContext,
  expected spec: DiagnosticSpec,
  failureHandler: (TestFailureSpec) -> Void
) {
  if let id = spec.id, diag.diagnosticID != id {
    failureHandler(
      TestFailureSpec(
        message: "diagnostic ID \(diag.diagnosticID) does not match expected id \(id)",
        location: spec.failureLocation
      )
    )
  }
  assertStringsEqualWithDiff(
    diag.message,
    spec.message,
    "message does not match",
    location: spec.failureLocation.underlying,
    failureHandler: { failureHandler(TestFailureSpec(underlying: $0)) }
  )
  let location = expansionContext.location(for: diag.position, anchoredAt: diag.node, fileName: "")
  if location.line != spec.line {
    failureHandler(
      TestFailureSpec(
        message: "line \(location.line) does not match expected line \(spec.line)",
        location: spec.failureLocation
      )
    )
  }
  if location.column != spec.column {
    failureHandler(
      TestFailureSpec(
        message: "column \(location.column) does not match expected column \(spec.column)",
        location: spec.failureLocation
      )
    )
  }

  if spec.severity != diag.diagMessage.severity {
    failureHandler(
      TestFailureSpec(
        message: "severity \(diag.diagMessage.severity) does not match expected severity \(spec.severity)",
        location: spec.failureLocation
      )
    )
  }

  if let highlights = spec.highlights {
    if diag.highlights.count != highlights.count {
      failureHandler(
        TestFailureSpec(
          message: """
            Expected \(highlights.count) highlights but received \(diag.highlights.count):
            \(diag.highlights.map(\.trimmedDescription).joined(separator: "\n"))
            """,
          location: spec.failureLocation
        )
      )
    } else {
      for (actual, expected) in zip(diag.highlights, highlights) {
        assertStringsEqualWithDiff(
          actual.trimmedDescription,
          expected,
          "highlight does not match",
          location: spec.failureLocation.underlying,
          failureHandler: { failureHandler(TestFailureSpec(underlying: $0)) }
        )
      }
    }
  }
  if diag.notes.count != spec.notes.count {
    failureHandler(
      TestFailureSpec(
        message: """
          Expected \(spec.notes.count) notes but received \(diag.notes.count):
          \(diag.notes.map(\.debugDescription).joined(separator: "\n"))
          """,
        location: spec.failureLocation
      )
    )
  } else {
    for (note, expectedNote) in zip(diag.notes, spec.notes) {
      assertNote(note, in: expansionContext, expected: expectedNote, failureHandler: failureHandler)
    }
  }
  if diag.fixIts.count != spec.fixIts.count {
    failureHandler(
      TestFailureSpec(
        message: """
          Expected \(spec.fixIts.count) Fix-Its but received \(diag.fixIts.count):
          \(diag.fixIts.map(\.message.message).joined(separator: "\n"))
          """,
        location: spec.failureLocation
      )
    )
  } else {
    for (fixIt, expectedFixIt) in zip(diag.fixIts, spec.fixIts) {
      assertFixIt(fixIt, expected: expectedFixIt, failureHandler: failureHandler)
    }
  }
}

/// Assert that expanding the given macros in the original source produces
/// the given expanded source code.
///
/// - Parameters:
///   - originalSource: The original source code, which is expected to contain
///     macros in various places (e.g., `#stringify(x + y)`).
///   - expectedExpandedSource: The source code that we expect to see after
///     performing macro expansion on the original source.
///   - diagnostics: The diagnostics when expanding any macro
///   - macroSpecs: The macros that should be expanded, provided as a dictionary
///     mapping macro names (e.g., `"CodableMacro"`) to specification with macro type
///     (e.g., `CodableMacro.self`) and a list of conformances macro provides
///     (e.g., `["Decodable", "Encodable"]`).
///   - applyFixIts: If specified, filters the Fix-Its that are applied to generate `fixedSource` to only those whose message occurs in this array. If `nil`, all Fix-Its from the diagnostics are applied.
///   - fixedSource: If specified, asserts that the source code after applying Fix-Its matches this string.
///   - testModuleName: The name of the test module to use.
///   - testFileName: The name of the test file name to use.
///   - indentationWidth: The indentation width used in the expansion.
public func assertMacroExpansion(
  _ originalSource: String,
  expandedSource expectedExpandedSource: String,
  diagnostics: [DiagnosticSpec] = [],
  macroSpecs: [String: MacroSpec],
  applyFixIts: [String]? = nil,
  fixedSource expectedFixedSource: String? = nil,
  testModuleName: String = "TestModule",
  testFileName: String = "test.swift",
  indentationWidth: Trivia = .spaces(4),
  failureHandler: (TestFailureSpec) -> Void,
  fileID: StaticString = #fileID,
  filePath: StaticString = #filePath,
  line: UInt = #line,
  column: UInt = #column
) {
  let failureLocation = TestFailureLocation(fileID: fileID, filePath: filePath, line: line, column: column)
  // Parse the original source file.
  let origSourceFile = Parser.parse(source: originalSource)

  // Expand all macros in the source.
  let context = BasicMacroExpansionContext(
    sourceFiles: [origSourceFile: .init(moduleName: testModuleName, fullFilePath: testFileName)]
  )

  func contextGenerator(_ syntax: Syntax) -> BasicMacroExpansionContext {
    return BasicMacroExpansionContext(sharingWith: context, lexicalContext: syntax.allMacroLexicalContexts())
  }

  let expandedSourceFile = origSourceFile.expand(
    macroSpecs: macroSpecs,
    contextGenerator: contextGenerator,
    indentationWidth: indentationWidth
  )
  let diags = ParseDiagnosticsGenerator.diagnostics(for: expandedSourceFile)
  if !diags.isEmpty {
    failureHandler(
      TestFailureSpec(
        message: """
          Expanded source should not contain any syntax errors, but contains:
          \(DiagnosticsFormatter.annotatedSource(tree: expandedSourceFile, diags: diags))

          Expanded syntax tree was:
          \(expandedSourceFile.debugDescription)
          """,
        location: failureLocation
      )
    )
  }

  assertStringsEqualWithDiff(
    expandedSourceFile.description.drop(while: \.isNewline).droppingLast(while: \.isNewline),
    expectedExpandedSource.drop(while: \.isNewline).droppingLast(while: \.isNewline),
    "Macro expansion did not produce the expected expanded source",
    additionalInfo: """
      Actual expanded source:
      \(expandedSourceFile)
      """,
    location: failureLocation.underlying,
    failureHandler: { failureHandler(TestFailureSpec(underlying: $0)) }
  )

  if context.diagnostics.count != diagnostics.count {
    failureHandler(
      TestFailureSpec(
        message: """
          Expected \(diagnostics.count) diagnostics but received \(context.diagnostics.count):
          \(context.diagnostics.map(\.debugDescription).joined(separator: "\n"))
          """,
        location: failureLocation
      )
    )
  } else {
    for (actualDiag, expectedDiag) in zip(context.diagnostics, diagnostics) {
      assertDiagnostic(actualDiag, in: context, expected: expectedDiag, failureHandler: failureHandler)
    }
  }

  // Applying Fix-Its
  if let expectedFixedSource = expectedFixedSource {
    let messages = applyFixIts ?? context.diagnostics.compactMap { $0.fixIts.first?.message.message }

    let edits =
      context.diagnostics
      .flatMap(\.fixIts)
      .filter { messages.contains($0.message.message) }
      .flatMap { $0.changes }
      .map { $0.edit(in: context) }

    let fixedTree = FixItApplier.apply(edits: edits, to: origSourceFile)
    let fixedTreeDescription = fixedTree.description
    assertStringsEqualWithDiff(
      fixedTreeDescription.trimmingTrailingWhitespace(),
      expectedFixedSource.trimmingTrailingWhitespace(),
      location: failureLocation.underlying,
      failureHandler: { failureHandler(TestFailureSpec(underlying: $0)) }
    )
  }
}

fileprivate extension FixIt.Change {
  /// Returns the edit for this change, translating positions from detached nodes
  /// to the corresponding locations in the original source file based on
  /// `expansionContext`.
  ///
  /// - SeeAlso: `FixIt.Change.edit`
  func edit(in expansionContext: BasicMacroExpansionContext) -> SourceEdit {
    switch self {
    case .replace(let oldNode, let newNode):
      let start = expansionContext.position(of: oldNode.position, anchoredAt: oldNode)
      let end = expansionContext.position(of: oldNode.endPosition, anchoredAt: oldNode)
      return SourceEdit(
        range: start..<end,
        replacement: newNode.description
      )

    case .replaceLeadingTrivia(let token, let newTrivia):
      let start = expansionContext.position(of: token.position, anchoredAt: token)
      let end = expansionContext.position(of: token.positionAfterSkippingLeadingTrivia, anchoredAt: token)
      return SourceEdit(
        range: start..<end,
        replacement: newTrivia.description
      )

    case .replaceTrailingTrivia(let token, let newTrivia):
      let start = expansionContext.position(of: token.endPositionBeforeTrailingTrivia, anchoredAt: token)
      let end = expansionContext.position(of: token.endPosition, anchoredAt: token)
      return SourceEdit(
        range: start..<end,
        replacement: newTrivia.description
      )
    }
  }
}

fileprivate extension BasicMacroExpansionContext {
  /// Translates a position from a detached node to the corresponding position
  /// in the original source file.
  func position(
    of position: AbsolutePosition,
    anchoredAt node: some SyntaxProtocol
  ) -> AbsolutePosition {
    let location = self.location(for: position, anchoredAt: Syntax(node), fileName: "")
    return AbsolutePosition(utf8Offset: location.offset)
  }
}
