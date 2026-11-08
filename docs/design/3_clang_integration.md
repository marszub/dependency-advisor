# 3. Clang AST Integration and Implementation

> **Rule:** No file outside of the AST extraction module shall mention Clang, `clang::`, or LibTooling headers. The rest of the engine deals entirely with language-agnostic graph abstractions.

## Responsibilities of the Clang Integration Layer

The Clang module acts as a translator between C++ source files and our abstract graph representation. It uses Clang's LibTooling and AST visitors to inspect code constructs.

### 1. Extracting Function Calls (`CallExpr`)
* Traverses `clang::CallExpr` nodes.
* Resolves direct callees via `call->getDirectCallee()`.
* Identifies caller and callee fully qualified names and file locations.

### 2. Extracting Data Access (`MemberExpr`)
* Traverses `clang::MemberExpr` nodes.
* Identifies when a function accesses a field (`FieldDecl`) belonging to a `CXXRecordDecl`.
* Emits a data-access edge from the enclosing function to the data member/class.

### 3. Extracting Type References (`QualType` / `TypeLoc`)
* Inspects function parameter types and return types.
* Emits edges for referenced class types.

### 4. Output Contract
The Clang extraction module passes its findings directly into an **in-memory data structure and graph representation** (e.g., in-memory adjacency lists, node/edge structs, or an in-memory graph database/repository). No intermediate files (like JSON on disk) are required, keeping the extraction and analysis pipeline entirely memory-resident and fast.
