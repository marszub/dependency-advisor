# 4. Mathematical Problem, Objective Function, and Algorithms

## 1. Problem Statement
Given a weighted graph $G = (V, E)$ where $V$ is the set of functions and $E$ represents interaction weights (calls, data access), find a partitioning function $P: V \to \{1, 2, \dots, K\}$ (mapping each function to a class group) that optimizes internal cohesion and minimizes external coupling.

## 2. Objective Function
We formulate this as a modularity maximization / cost-minimization problem. Let $w(u, v)$ be the weight of the edge between function $u$ and function $v$. 

The objective is to **maximize**:
$$\text{Score}(P) = \sum_{C \in P} \left( \sum_{u, v \in C} w(u, v) \right) - \lambda \sum_{C_i \neq C_j} \left( \sum_{u \in C_i, v \in C_j} w(u, v) \right)$$

Where:
* The first term rewards edges within the same class group (Cohesion).
* The second term penalizes edges crossing class boundaries (Coupling).
* $\lambda$ is a tuning parameter balancing internal density against cross-class communication.

## 3. Algorithmic Approaches

### A. Exact Solution (Integer Linear Programming / Brute Force)
* **Complexity:** NP-Hard (resembles Graph Partitioning / Minimum Cut / Modularity Maximization).
* **Feasibility:** Impractical for codebases with thousands of functions ($O(2^N)$ or factorial search spaces). Useful only for tiny micro-benchmarks or sub-graphs.

### B. Heuristics & Approximate Algorithms (Recommended)

1. **Louvain Community Detection / Leiden Algorithm:**
   * **Concept:** Greedily optimizes modularity by moving nodes between communities locally, then building a coarser graph of communities.
   * **Time Complexity:** $O(N \log N)$ on sparse graphs.
   * **Suitability:** Excellent for discovering natural class groupings in large codebases.

2. **Hierarchical Agglomerative Clustering (HAC):**
   * **Concept:** Starts with every function in its own class, then iteratively merges the pairs of classes with the highest inter-group interaction weights until $K$ classes remain.
   * **Time Complexity:** $O(N^2 \log N)$ or $O(N^3)$ depending on linkage criteria.
   * **Suitability:** Great when the target number of classes $K$ is known or constrained.

3. **Spectral Partitioning:**
   * **Concept:** Uses the eigenvalues and eigenvectors of the graph's Laplacian matrix to partition nodes into balanced groups.
   * **Time Complexity:** $O(N^3)$ for eigenvalue decomposition.
   * **Suitability:** Good for balanced bi-partitioning (e.g., splitting a bloated class into two halves).
