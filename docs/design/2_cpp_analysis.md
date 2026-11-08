# 2. C++ Language Analysis: Nodes, Edges, and Groups

To model a C++ codebase for refactoring, we must define what constitutes a **node**, an **edge**, and a **group** in the language domain.

## 1. Nodes: The Code Units
In our dependency model, the primary **nodes** of the graph are **functions** (both free functions and member methods/constructors/destructors). 
* *Why functions?* Functions represent the operational behavior of code. By deciding which class should "own" each function, we define the class structure.
* Secondary nodes may include **data members** (fields), which act as gravitational anchors for the functions that access them.

## 2. Edges: The Dependencies (Interactions)
Edges represent relationships between nodes and carry weights corresponding to interaction strength. The dependency types include:

* **Direct Function Calls ($w_{call}$):** When function $A$ calls function $B$. Frequent calls indicate execution coupling.
* **Data Member Access ($w_{data}$):** When function $A$ reads or writes member variable $m$ (owned by class $C$). This is a very strong anchor indicating that $A$ belongs near $C$.
* **Type Usage ($w_{type}$):** When function $A$ accepts parameters or returns types defined in class $C$.
* **Friendship ($w_{friend}$):** Explicit `friend` declarations indicating intended tight coupling.

## 3. Groups: Classes and Modules
* **Current Groups:** The existing class hierarchy or file boundaries in the codebase.
* **Target Groups:** The optimized partition of functions into classes ($C_1, C_2, \dots, C_k$) that maximizes internal interactions while minimizing cross-group calls.
