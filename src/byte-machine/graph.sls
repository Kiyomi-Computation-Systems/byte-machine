;;; SPDX-License-Identifier: BSD-3-Clause
;;; (byte-machine graph): the public construction API. It re-exports the
;;; source-IR constructors, predicates and accessors from the private ir library
;;; so grammar authors build machines without touching internals. Constructors
;;; validate local shape only; whole-machine verification is (byte-machine
;;; verify)'s job.
;;;
;;; What is deliberately withheld from this surface: matcher-bytes -- the
;;; internal canonicalization spine the verifier, normalizer and interpreter
;;; share -- is not re-exported, being no part of the construction API. Machine
;;; accessors are likewise private: this library fixes a construction surface,
;;; and reading a built machine back is not part of it. Most node kinds are
;;; re-exported as constructors only; their predicates and accessors stay in the
;;; private library. The exceptions surfaced here are the matcher family and the
;;; sequence-dispatch node/case, whose predicates and accessors are re-exported.
;;;
;;; Signatures of the re-exported families (types: see (byte-machine private ir)):
;;;
;;;   Machine / node / declaration constructors --
;;;   make-machine : Symbol NodeName (Listof UintField) (Listof CallbackDeclaration)
;;;                  (Listof SpanDeclaration) (Listof ErrorDeclaration) (Listof Node)
;;;                  ErrorName Label -> Machine
;;;   make-byte-dispatch-node : Symbol (Listof ByteCase) Edge (Option NodeName) Label
;;;                             -> ByteDispatchNode
;;;   make-sequence-dispatch-node : Symbol (Listof SequenceCase) Edge (Option NodeName)
;;;                                 Label -> SequenceDispatchNode
;;;   make-stop-node   : Symbol Label -> StopNode
;;;   make-finish-node : Symbol Label -> FinishNode
;;;   make-pause-node  : Symbol NodeName [ErrorName] Label -> PauseNode
;;;                      (the optional ErrorName is the pause's reason)
;;;   make-error-node  : Symbol ErrorName Label -> ErrorNode
;;;   make-field-action-node : Symbol FieldOperation (Listof (U Symbol ExactInteger))
;;;                            NodeName (Option NodeName) Label -> FieldActionNode
;;;   make-field-branch-node : Symbol FieldPredicate (Listof (U Symbol ExactInteger))
;;;                            NodeName NodeName Label -> FieldBranchNode
;;;   make-integer-accumulate-node : Symbol Symbol AccumulateBase NodeName Edge NodeName
;;;                                  (Option NodeName) Label -> IntegerAccumulateNode
;;;   make-callback-node : Symbol Symbol NodeName (Listof (List Symbol NodeName)) NodeName
;;;                        [ErrorName] Label -> CallbackNode
;;;                        (the optional ErrorName is the callback-pause reason)
;;;   make-span-start-node : Symbol Symbol NodeName Label -> SpanStartNode
;;;   make-span-end-node   : Symbol Symbol NodeName Label -> SpanEndNode
;;;   make-counted-consume-node : Symbol Symbol NodeName (Option NodeName) Label
;;;                               -> CountedConsumeNode
;;;   make-byte-case     : Matcher Edge Label -> ByteCase
;;;   make-sequence-case : (Listof Byte) NodeName Label -> SequenceCase
;;;   make-keyword-table-node : Symbol (Listof KeywordEntry) Edge (Option NodeName)
;;;                             Boolean Label -> KeywordTableNode
;;;   make-keyword-entry : (Listof Byte) NodeName Label -> KeywordEntry
;;;   make-edge          : NodeName EdgeMode -> Edge
;;;   make-uint-field    : Symbol UintWidth ExactInteger [Boolean] Label -> UintField
;;;   make-callback-declaration : Symbol CallbackKind Boolean (Listof Symbol)
;;;                               (Option Symbol) Label -> CallbackDeclaration
;;;   make-span-declaration  : Symbol Symbol (Option Symbol) Label -> SpanDeclaration
;;;   make-error-declaration : Symbol Symbol String Label -> ErrorDeclaration
;;;
;;;   Matcher constructors and text helper --
;;;   make-exact-byte-matcher      : Byte -> ExactByteMatcher
;;;   make-byte-set-matcher        : (Listof Byte) -> ByteSetMatcher
;;;   make-byte-range-matcher      : Byte Byte -> ByteRangeMatcher
;;;   make-byte-complement-matcher : Matcher -> ByteComplementMatcher
;;;   ascii-bytes                  : String -> (Listof Byte)
;;;
;;;   Matcher predicates and accessors --
;;;   matcher?                        : Any -> Boolean
;;;   exact-byte-matcher?             : Any -> Boolean
;;;   exact-byte-matcher-byte         : ExactByteMatcher -> Byte
;;;   byte-set-matcher?               : Any -> Boolean
;;;   byte-set-matcher-bytes          : ByteSetMatcher -> (Listof Byte)   ; fresh copy
;;;   byte-range-matcher?             : Any -> Boolean
;;;   byte-range-matcher-low          : ByteRangeMatcher -> Byte
;;;   byte-range-matcher-high         : ByteRangeMatcher -> Byte
;;;   byte-complement-matcher?        : Any -> Boolean
;;;   byte-complement-matcher-matcher : ByteComplementMatcher -> Matcher
;;;
;;;   uint-field family --
;;;   uint-field?             : Any -> Boolean
;;;   uint-field-name         : UintField -> Symbol
;;;   uint-field-width        : UintField -> UintWidth
;;;   uint-field-initial      : UintField -> ExactInteger
;;;   uint-field-settable?    : UintField -> Boolean
;;;   uint-field-source-label : UintField -> Label
;;;
;;;   callback-declaration family --
;;;   callback-declaration?               : Any -> Boolean
;;;   callback-declaration-name           : CallbackDeclaration -> Symbol
;;;   callback-declaration-kind           : CallbackDeclaration -> CallbackKind
;;;   callback-declaration-required?      : CallbackDeclaration -> Boolean
;;;   callback-declaration-branch-keys    : CallbackDeclaration -> (Listof Symbol)
;;;   callback-declaration-default-branch : CallbackDeclaration -> (Option Symbol)
;;;   callback-declaration-source-label   : CallbackDeclaration -> Label
;;;
;;;   span-declaration family --
;;;   span-declaration?                  : Any -> Boolean
;;;   span-declaration-name              : SpanDeclaration -> Symbol
;;;   span-declaration-data-callback     : SpanDeclaration -> Symbol
;;;   span-declaration-complete-callback : SpanDeclaration -> (Option Symbol)
;;;   span-declaration-source-label      : SpanDeclaration -> Label
;;;
;;;   sequence-dispatch-node / sequence-case accessors --
;;;   sequence-dispatch-node?           : Any -> Boolean
;;;   sequence-dispatch-node-name       : SequenceDispatchNode -> Symbol
;;;   sequence-dispatch-node-cases      : SequenceDispatchNode -> (Listof SequenceCase)
;;;   sequence-dispatch-node-mismatch   : SequenceDispatchNode -> Edge
;;;   sequence-dispatch-node-eof-target : SequenceDispatchNode -> (Option NodeName)
;;;   sequence-case?                    : Any -> Boolean
;;;   sequence-case-bytes               : SequenceCase -> (Listof Byte)   ; fresh copy
;;;   sequence-case-target              : SequenceCase -> NodeName
(library (byte-machine graph)
  (export make-uint-field uint-field? uint-field-name uint-field-width
          uint-field-initial uint-field-settable? uint-field-source-label
          make-callback-declaration callback-declaration?
          callback-declaration-name callback-declaration-kind
          callback-declaration-required? callback-declaration-branch-keys
          callback-declaration-default-branch callback-declaration-source-label
          make-span-declaration span-declaration? span-declaration-name
          span-declaration-data-callback span-declaration-complete-callback
          span-declaration-source-label
          make-machine make-byte-dispatch-node make-byte-case
          make-exact-byte-matcher make-edge make-stop-node make-finish-node
          make-pause-node make-error-node make-error-declaration
          make-field-action-node make-field-branch-node
          make-integer-accumulate-node make-callback-node
          make-span-start-node make-span-end-node make-counted-consume-node
          make-byte-set-matcher make-byte-range-matcher
          make-byte-complement-matcher ascii-bytes
          matcher? exact-byte-matcher? exact-byte-matcher-byte
          byte-set-matcher? byte-set-matcher-bytes
          byte-range-matcher? byte-range-matcher-low byte-range-matcher-high
          byte-complement-matcher? byte-complement-matcher-matcher
          make-sequence-dispatch-node make-sequence-case
          sequence-dispatch-node? sequence-dispatch-node-name
          sequence-dispatch-node-cases sequence-dispatch-node-mismatch
          sequence-dispatch-node-eof-target
          sequence-case? sequence-case-bytes sequence-case-target
          make-keyword-table-node make-keyword-entry)
  (import (only (byte-machine private ir)
                make-uint-field uint-field? uint-field-name uint-field-width
                uint-field-initial uint-field-settable? uint-field-source-label
                make-callback-declaration callback-declaration?
                callback-declaration-name callback-declaration-kind
                callback-declaration-required? callback-declaration-branch-keys
                callback-declaration-default-branch
                callback-declaration-source-label
                make-span-declaration span-declaration? span-declaration-name
                span-declaration-data-callback
                span-declaration-complete-callback
                span-declaration-source-label
                make-machine make-byte-dispatch-node make-byte-case
                make-exact-byte-matcher make-edge make-stop-node make-finish-node
                make-pause-node make-error-node make-error-declaration
                make-field-action-node make-field-branch-node
                make-integer-accumulate-node make-callback-node
                make-span-start-node make-span-end-node make-counted-consume-node
                make-byte-set-matcher make-byte-range-matcher
                make-byte-complement-matcher ascii-bytes
                matcher? exact-byte-matcher? exact-byte-matcher-byte
                byte-set-matcher? byte-set-matcher-bytes
                byte-range-matcher? byte-range-matcher-low byte-range-matcher-high
                byte-complement-matcher? byte-complement-matcher-matcher
                make-sequence-dispatch-node make-sequence-case
                sequence-dispatch-node? sequence-dispatch-node-name
                sequence-dispatch-node-cases sequence-dispatch-node-mismatch
                sequence-dispatch-node-eof-target
                sequence-case? sequence-case-bytes sequence-case-target
                make-keyword-table-node make-keyword-entry)))
