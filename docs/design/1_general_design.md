# 1. General Design, Goals, and High-Level Problem Explanation

## Introduction & Vision

In large and evolving C++ codebases, code organization often drifts away from optimal software engineering principles. Functions are placed in monolithic helper files, data members and methods become loosely coupled, and classes grow too large or fragmented. Refactoring such code manually is tedious, error-prone, and subjective.

The **Dependency Advisor** is an automated tool designed to inspect a C++ project, analyze how functions interact with each other and with data, and recommend a better structural organization (such as splitting classes, regrouping functions, or moving methods into appropriate classes).

## Core Goals

1. **Objective Restructuring:** Replace subjective code organization opinions with graph-theoretic metrics based on actual code usage.
2. **Maximize Cohesion:** Ensure that functions that work together closely reside within the same class or module.
3. **Minimize Coupling:** Reduce the interdependencies between different classes and modules to improve testability, compilation times, and maintainability.
4. **Decoupled Architecture:** Maintain a clean separation between raw C++ parsing (Clang AST) and the core analytical graph optimization algorithms.

## High-Level Workflow

The system is split into distinct layers:
1. **Extraction Layer:** Parses C++ source files using Clang to extract raw code entities and relationships without leaking Clang dependencies into the rest of the engine.
2. **Model Layer:** Translates the extracted data into a language-agnostic graph model where functions are nodes and relationships are weighted edges.
3. **Optimization Layer:** Solves the graph partitioning / community detection problem to find the optimal grouping of functions into classes.
4. **Reporting Layer:** Outputs clear refactoring suggestions (e.g., *"Move function `foo` from class `A` to class `B`"*).
