//===--- Flatten.swift ----------------------------------------*- swift -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// An iterator that produces the elements contained in each segment
/// produced by some `Base` Iterator.
///
/// The elements traversed are the concatenation of those in each
/// segment produced by the base iterator.
///
/// - Note: This is the `IteratorProtocol` used by `FlattenSequence`,
///   `FlattenCollection`, and `BidirectionalFlattenCollection`.
@_fixed_layout // FIXME(sil-serialize-all)
public struct FlattenIterator<Base : IteratorProtocol> : IteratorProtocol, Sequence
  where Base.Element : Sequence {

  /// Construct around a `base` iterator.
  @_inlineable // FIXME(sil-serialize-all)
  @_versioned // FIXME(sil-serialize-all)
  internal init(_base: Base) {
    self._base = _base
  }

  /// Advances to the next element and returns it, or `nil` if no next element
  /// exists.
  ///
  /// Once `nil` has been returned, all subsequent calls return `nil`.
  ///
  /// - Precondition: `next()` has not been applied to a copy of `self`
  ///   since the copy was made.
  @_inlineable // FIXME(sil-serialize-all)
  public mutating func next() -> Base.Element.Element? {
    repeat {
      if _fastPath(_inner != nil) {
        let ret = _inner!.next()
        if _fastPath(ret != nil) {
          return ret
        }
      }
      let s = _base.next()
      if _slowPath(s == nil) {
        return nil
      }
      _inner = s!.makeIterator()
    }
    while true
  }

  @_versioned // FIXME(sil-serialize-all)
  internal var _base: Base
  @_versioned // FIXME(sil-serialize-all)
  internal var _inner: Base.Element.Iterator?
}

/// A sequence consisting of all the elements contained in each segment
/// contained in some `Base` sequence.
///
/// The elements of this view are a concatenation of the elements of
/// each sequence in the base.
///
/// The `joined` method is always lazy, but does not implicitly
/// confer laziness on algorithms applied to its result.  In other
/// words, for ordinary sequences `s`:
///
/// * `s.joined()` does not create new storage
/// * `s.joined().map(f)` maps eagerly and returns a new array
/// * `s.lazy.joined().map(f)` maps lazily and returns a `LazyMapSequence`
///
/// - See also: `FlattenCollection`
@_fixed_layout // FIXME(sil-serialize-all)
public struct FlattenSequence<Base : Sequence> : Sequence
  where Base.Element : Sequence {

  /// Creates a concatenation of the elements of the elements of `base`.
  ///
  /// - Complexity: O(1)
  @_inlineable // FIXME(sil-serialize-all)
  @_versioned // FIXME(sil-serialize-all)
  internal init(_base: Base) {
    self._base = _base
  }

  /// Returns an iterator over the elements of this sequence.
  ///
  /// - Complexity: O(1).
  @_inlineable // FIXME(sil-serialize-all)
  public func makeIterator() -> FlattenIterator<Base.Iterator> {
    return FlattenIterator(_base: _base.makeIterator())
  }

  @_versioned // FIXME(sil-serialize-all)
  internal var _base: Base
}

extension Sequence where Element : Sequence {
  /// Returns the elements of this sequence of sequences, concatenated.
  ///
  /// In this example, an array of three ranges is flattened so that the
  /// elements of each range can be iterated in turn.
  ///
  ///     let ranges = [0..<3, 8..<10, 15..<17]
  ///
  ///     // A for-in loop over 'ranges' accesses each range:
  ///     for range in ranges {
  ///       print(range)
  ///     }
  ///     // Prints "0..<3"
  ///     // Prints "8..<10"
  ///     // Prints "15..<17"
  ///
  ///     // Use 'joined()' to access each element of each range:
  ///     for index in ranges.joined() {
  ///         print(index, terminator: " ")
  ///     }
  ///     // Prints: "0 1 2 8 9 15 16"
  ///
  /// - Returns: A flattened view of the elements of this
  ///   sequence of sequences.
  @_inlineable // FIXME(sil-serialize-all)
  public func joined() -> FlattenSequence<Self> {
    return FlattenSequence(_base: self)
  }
}

extension LazySequenceProtocol where Element : Sequence {

  /// Returns a lazy sequence that concatenates the elements of this sequence of
  /// sequences.
  @_inlineable // FIXME(sil-serialize-all)
  public func joined() -> LazySequence<
    FlattenSequence<Elements>
  > {
    return FlattenSequence(_base: elements).lazy
  }
}

/// A position in a FlattenCollection
@_fixed_layout // FIXME(sil-serialize-all)
public struct FlattenCollectionIndex<BaseElements>
  where
  BaseElements : Collection,
  BaseElements.Element : Collection {

  @_inlineable // FIXME(sil-serialize-all)
  @_versioned // FIXME(sil-serialize-all)
  internal init(
    _ _outer: BaseElements.Index,
    _ inner: BaseElements.Element.Index?) {
    self._outer = _outer
    self._inner = inner
  }

  /// The position in the outer collection of collections.
  @_versioned // FIXME(sil-serialize-all)
  internal let _outer: BaseElements.Index

  /// The position in the inner collection at `base[_outer]`, or `nil` if
  /// `_outer == base.endIndex`.
  ///
  /// When `_inner != nil`, `_inner!` is a valid subscript of `base[_outer]`;
  /// when `_inner == nil`, `_outer == base.endIndex` and this index is
  /// `endIndex` of the `FlattenCollection`.
  @_versioned // FIXME(sil-serialize-all)
  internal let _inner: BaseElements.Element.Index?
}

extension FlattenCollectionIndex : Equatable {
  @_inlineable // FIXME(sil-serialize-all)
  public static func == (
    lhs: FlattenCollectionIndex<BaseElements>,
    rhs: FlattenCollectionIndex<BaseElements>
  ) -> Bool {
    return lhs._outer == rhs._outer && lhs._inner == rhs._inner
  }
}

extension FlattenCollectionIndex : Comparable {
  @_inlineable // FIXME(sil-serialize-all)
  public static func < (
    lhs: FlattenCollectionIndex<BaseElements>,
    rhs: FlattenCollectionIndex<BaseElements>
  ) -> Bool {
    // FIXME: swift-3-indexing-model: tests.
    if lhs._outer != rhs._outer {
      return lhs._outer < rhs._outer
    }

    if let lhsInner = lhs._inner, let rhsInner = rhs._inner {
      return lhsInner < rhsInner
    }

    // When combined, the two conditions above guarantee that both
    // `_outer` indices are `_base.endIndex` and both `_inner` indices
    // are `nil`, since `_inner` is `nil` iff `_outer == base.endIndex`.
    _precondition(lhs._inner == nil && rhs._inner == nil)

    return false
  }
}

extension FlattenCollectionIndex : Hashable
  where BaseElements.Index : Hashable, BaseElements.Element.Index : Hashable {
  public var hashValue: Int {
    return _mixInt(_inner?.hashValue ?? 0) ^ _outer.hashValue
  }
}

/// A flattened view of a base collection of collections.
///
/// The elements of this view are a concatenation of the elements of
/// each collection in the base.
///
/// The `joined` method is always lazy, but does not implicitly
/// confer laziness on algorithms applied to its result.  In other
/// words, for ordinary collections `c`:
///
/// * `c.joined()` does not create new storage
/// * `c.joined().map(f)` maps eagerly and returns a new array
/// * `c.lazy.joined().map(f)` maps lazily and returns a `LazyMapCollection`
///
/// - Note: The performance of accessing `startIndex`, `first`, any methods
///   that depend on `startIndex`, or of advancing a `FlattenCollectionIndex`
///   depends on how many empty subcollections are found in the base
///   collection, and may not offer the usual performance given by `Collection`
///   or `Index`. Be aware, therefore, that general operation on
///   `FlattenCollection` instances may not have the documented complexity.
///
/// - See also: `FlattenSequence`
@_fixed_layout // FIXME(sil-serialize-all)
public struct FlattenCollection<Base>
  where Base : Collection, Base.Element : Collection {
  // FIXME: swift-3-indexing-model: check test coverage for collection.

  @_versioned // FIXME(sil-serialize-all)
  internal var _base: Base

  /// Creates a flattened view of `base`.
  @_inlineable // FIXME(sil-serialize-all)
  public init(_ base: Base) {
    self._base = base
  }
}

extension FlattenCollection : Sequence {
  public typealias SubSequence = Slice<FlattenCollection>
  /// Returns an iterator over the elements of this sequence.
  ///
  /// - Complexity: O(1).
  @_inlineable // FIXME(sil-serialize-all)
  public func makeIterator() -> FlattenIterator<Base.Iterator> {
    return FlattenIterator(_base: _base.makeIterator())
  }

  // To return any estimate of the number of elements, we have to start
  // evaluating the collections.  That is a bad default for `flatMap()`, so
  // just return zero.
  public var underestimatedCount: Int { return 0 }

  @_inlineable // FIXME(sil-serialize-all)
  public func _copyToContiguousArray()
    -> ContiguousArray<Base.Element.Element> {

    // The default implementation of `_copyToContiguousArray` queries the
    // `count` property, which materializes every inner collection.  This is a
    // bad default for `flatMap()`.  So we treat `self` as a sequence and only
    // rely on underestimated count.
    return _copySequenceToContiguousArray(self)
  }

  // TODO: swift-3-indexing-model - add docs
  @_inlineable // FIXME(sil-serialize-all)
  public func forEach(
    _ body: (Base.Element.Element) throws -> Void
  ) rethrows {
    // FIXME: swift-3-indexing-model: tests.
    for innerCollection in _base {
      try innerCollection.forEach(body)
    }
  }
}

extension FlattenCollection : Collection {
  /// A type that represents a valid position in the collection.
  ///
  /// Valid indices consist of the position of every element and a
  /// "past the end" position that's not valid for use as a subscript.
  public typealias Index = FlattenCollectionIndex<Base>

  /// The position of the first element in a non-empty collection.
  ///
  /// In an empty collection, `startIndex == endIndex`.
  @_inlineable // FIXME(sil-serialize-all)
  public var startIndex: Index {
    let end = _base.endIndex
    var outer = _base.startIndex
    while outer != end {
      let innerCollection = _base[outer]
      if !innerCollection.isEmpty {
        return FlattenCollectionIndex(outer, innerCollection.startIndex)
      }
      _base.formIndex(after: &outer)
    }

    return endIndex
  }

  /// The collection's "past the end" position.
  ///
  /// `endIndex` is not a valid argument to `subscript`, and is always
  /// reachable from `startIndex` by zero or more applications of
  /// `index(after:)`.
  @_inlineable // FIXME(sil-serialize-all)
  public var endIndex: Index {
    return FlattenCollectionIndex(_base.endIndex, nil)
  }

  @_inlineable // FIXME(sil-serialize-all)
  @_versioned // FIXME(sil-serialize-all)
  internal func _index(after i: Index) -> Index {
    let innerCollection = _base[i._outer]
    let nextInner = innerCollection.index(after: i._inner!)
    if _fastPath(nextInner != innerCollection.endIndex) {
      return FlattenCollectionIndex(i._outer, nextInner)
    }

    var nextOuter = _base.index(after: i._outer)
    while nextOuter != _base.endIndex {
      let nextInnerCollection = _base[nextOuter]
      if !nextInnerCollection.isEmpty {
        return FlattenCollectionIndex(
          nextOuter, nextInnerCollection.startIndex)
      }
      _base.formIndex(after: &nextOuter)
    }

    return endIndex
  }

  @_inlineable // FIXME(sil-serialize-all)
  @_versioned // FIXME(sil-serialize-all)
  internal func _index(before i: Index) -> Index {
    var prevOuter = i._outer
    if prevOuter == _base.endIndex {
      prevOuter = _base.index(prevOuter, offsetBy: -1)
    }
    var prevInnerCollection = _base[prevOuter]
    var prevInner = i._inner ?? prevInnerCollection.endIndex

    while prevInner == prevInnerCollection.startIndex {
      prevOuter = _base.index(prevOuter, offsetBy: -1)
      prevInnerCollection = _base[prevOuter]
      prevInner = prevInnerCollection.endIndex
    }

    return FlattenCollectionIndex(
      prevOuter, prevInnerCollection.index(prevInner, offsetBy: -1))
  }

  // TODO: swift-3-indexing-model - add docs
  @_inlineable // FIXME(sil-serialize-all)
  public func index(after i: Index) -> Index {
    return _index(after: i)
  }

  @_inlineable // FIXME(sil-serialize-all)
  public func formIndex(after i: inout Index) {
    i = index(after: i)
  }

  @_inlineable // FIXME(sil-serialize-all)
  public func distance(from start: Index, to end: Index) -> Int {
    // The following line makes sure that distance(from:to:) is invoked on the
    // _base at least once, to trigger a _precondition in forward only
    // collections.
    var _start: Index
    let _end: Index
    let step: Int
    if start > end {
      _start = end
      _end = start
      step = -1
    }
    else {
      _start = start
      _end = end
      step = 1
    }
    var count = 0
    while _start != _end {
      count += step
      formIndex(after: &_start)
    }
    return count
  }

  @inline(__always)
  @_inlineable // FIXME(sil-serialize-all)
  @_versioned // FIXME(sil-serialize-all)
  internal func _advanceIndex(_ i: inout Index, step: Int) {
    _sanityCheck(-1...1 ~= step, "step should be within the -1...1 range")
    i = step < 0 ? _index(before: i) : _index(after: i)
  }

  @inline(__always)
  @_inlineable // FIXME(sil-serialize-all)
  @_versioned // FIXME(sil-serialize-all)
  internal func _ensureBidirectional(step: Int) {
    // FIXME: This seems to be the best way of checking whether _base is
    // forward only without adding an extra protocol requirement.
    // index(_:offsetBy:limitedBy:) is chosen becuase it is supposed to return
    // nil when the resulting index lands outside the collection boundaries,
    // and therefore likely does not trap in these cases.
    if step < 0 {
      _ = _base.index(
        _base.endIndex, offsetBy: step, limitedBy: _base.startIndex)
    }
  }

  @_inlineable // FIXME(sil-serialize-all)
  public func index(_ i: Index, offsetBy n: Int) -> Index {
    var i = i
    let step = n.signum()
    _ensureBidirectional(step: step)
    for _ in 0 ..< abs(n) {
      _advanceIndex(&i, step: step)
    }
    return i
  }

  @_inlineable // FIXME(sil-serialize-all)
  public func formIndex(_ i: inout Index, offsetBy n: Int) {
    i = index(i, offsetBy: n)
  }

  @_inlineable // FIXME(sil-serialize-all)
  public func index(
    _ i: Index, offsetBy n: Int, limitedBy limit: Index
  ) -> Index? {
    var i = i
    let step = n.signum()
    // The following line makes sure that index(_:offsetBy:limitedBy:) is
    // invoked on the _base at least once, to trigger a _precondition in
    // forward only collections.
    _ensureBidirectional(step: step)
    for _ in 0 ..< abs(n) {
      if i == limit {
        return nil
      }
      _advanceIndex(&i, step: step)
    }
    return i
  }

  @_inlineable // FIXME(sil-serialize-all)
  public func formIndex(
    _ i: inout Index, offsetBy n: Int, limitedBy limit: Index
  ) -> Bool {
    if let advancedIndex = index(i, offsetBy: n, limitedBy: limit) {
      i = advancedIndex
      return true
    }
    i = limit
    return false
  }

  /// Accesses the element at `position`.
  ///
  /// - Precondition: `position` is a valid position in `self` and
  ///   `position != endIndex`.
  @_inlineable // FIXME(sil-serialize-all)
  public subscript(position: Index) -> Base.Element.Element {
    return _base[position._outer][position._inner!]
  }

  @_inlineable // FIXME(sil-serialize-all)
  public subscript(bounds: Range<Index>) -> SubSequence {
    return Slice(base: self, bounds: bounds)
  }
}

extension FlattenCollection : BidirectionalCollection
  where Base : BidirectionalCollection, Base.Element : BidirectionalCollection {

  // FIXME(performance): swift-3-indexing-model: add custom advance/distance
  // methods that skip over inner collections when random-access

  // TODO: swift-3-indexing-model - add docs
  @_inlineable // FIXME(sil-serialize-all)
  public func index(before i: Index) -> Index {
    return _index(before: i)
  }

  @_inlineable // FIXME(sil-serialize-all)
  public func formIndex(before i: inout Index) {
    i = index(before: i)
  }
}

extension Collection where Element : Collection {
  /// Returns the elements of this collection of collections, concatenated.
  ///
  /// In this example, an array of three ranges is flattened so that the
  /// elements of each range can be iterated in turn.
  ///
  ///     let ranges = [0..<3, 8..<10, 15..<17]
  ///
  ///     // A for-in loop over 'ranges' accesses each range:
  ///     for range in ranges {
  ///       print(range)
  ///     }
  ///     // Prints "0..<3"
  ///     // Prints "8..<10"
  ///     // Prints "15..<17"
  ///
  ///     // Use 'joined()' to access each element of each range:
  ///     for index in ranges.joined() {
  ///         print(index, terminator: " ")
  ///     }
  ///     // Prints: "0 1 2 8 9 15 16"
  ///
  /// - Returns: A flattened view of the elements of this
  ///   collection of collections.
  @_inlineable // FIXME(sil-serialize-all)
  public func joined() -> FlattenCollection<Self> {
    return FlattenCollection(self)
  }
}

extension BidirectionalCollection where Element : BidirectionalCollection {
  /// Returns the elements of this collection of collections, concatenated.
  ///
  /// In this example, an array of three ranges is flattened so that the
  /// elements of each range can be iterated in turn.
  ///
  ///     let ranges = [0..<3, 8..<10, 15..<17]
  ///
  ///     // A for-in loop over 'ranges' accesses each range:
  ///     for range in ranges {
  ///       print(range)
  ///     }
  ///     // Prints "0..<3"
  ///     // Prints "8..<10"
  ///     // Prints "15..<17"
  ///
  ///     // Use 'joined()' to access each element of each range:
  ///     for index in ranges.joined() {
  ///         print(index, terminator: " ")
  ///     }
  ///     // Prints: "0 1 2 8 9 15 16"
  ///
  /// - Returns: A flattened view of the elements of this
  ///   collection of collections.
  @_inlineable // FIXME(sil-serialize-all)
  public func joined() -> FlattenCollection<Self> {
    return FlattenCollection(self)
  }
}

extension LazyCollectionProtocol
  where Self : Collection, Element : Collection {
  /// A concatenation of the elements of `self`.
  @_inlineable // FIXME(sil-serialize-all)
  public func joined() -> LazyCollection<FlattenCollection<Elements>> {
    return FlattenCollection(elements).lazy
  }
}

extension LazyCollectionProtocol
  where Self : BidirectionalCollection, Element : BidirectionalCollection {
  /// A concatenation of the elements of `self`.
  @_inlineable // FIXME(sil-serialize-all)
  public func joined() -> LazyCollection<FlattenCollection<Elements>> {
    return FlattenCollection(elements).lazy
  }
}

@available(*, deprecated, renamed: "FlattenCollectionIndex")
public typealias FlattenBidirectionalCollectionIndex<T> = FlattenCollectionIndex<T> where T : BidirectionalCollection, T.Element : BidirectionalCollection
@available(*, deprecated, renamed: "FlattenCollection")
public typealias FlattenBidirectionalCollection<T> = FlattenCollection<T> where T : BidirectionalCollection, T.Element : BidirectionalCollection
