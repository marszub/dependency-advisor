#include <clang/AST/AST.h>
#include <clang/AST/RecursiveASTVisitor.h>
#include <clang/Frontend/ASTConsumers.h>
#include <clang/Frontend/FrontendActions.h>
#include <clang/Tooling/Tooling.h>
#include <clang/Tooling/CommonOptionsParser.h>
#include <llvm/Support/CommandLine.h>

#include <iostream>
#include <map>
#include <set>

using namespace clang;
using namespace clang::tooling;

class DependencyVisitor
    : public RecursiveASTVisitor<DependencyVisitor>
{
public:
    explicit DependencyVisitor(ASTContext *context)
        : context(context) {}

    bool VisitCallExpr(CallExpr *call)
    {
        const FunctionDecl *callee = call->getDirectCallee();
        if (!callee)
            return true;

        auto &sm = context->getSourceManager();

        SourceLocation callerLoc = call->getExprLoc();
        SourceLocation calleeLoc = callee->getLocation();

        std::string callerFile =
            sm.getFilename(callerLoc).str();

        std::string calleeFile =
            sm.getFilename(calleeLoc).str();

        // Filter out empty filenames and system headers
        if (!callerFile.empty() && !calleeFile.empty() &&
            callerFile.find("/usr/") == std::string::npos &&
            calleeFile.find("/usr/") == std::string::npos)
        {
            auto dep = std::make_pair(callerFile, calleeFile);
            if (reportedDependencies.find(dep) == reportedDependencies.end())
            {
                reportedDependencies.insert(dep);
                std::cout << callerFile
                          << " -> "
                          << calleeFile
                          << "\n";
            }
        }

        return true;
    }

private:
    ASTContext *context;
    std::set<std::pair<std::string, std::string>> reportedDependencies;
};

class DependencyConsumer : public ASTConsumer
{
public:
    explicit DependencyConsumer(ASTContext *context)
        : visitor(context) {}

    void HandleTranslationUnit(ASTContext &context) override
    {
        visitor.TraverseDecl(context.getTranslationUnitDecl());
    }

private:
    DependencyVisitor visitor;
};

class DependencyAction : public ASTFrontendAction
{
public:
    std::unique_ptr<ASTConsumer>
    CreateASTConsumer(CompilerInstance &CI,
                      llvm::StringRef file) override
    {
        return std::make_unique<DependencyConsumer>(
            &CI.getASTContext());
    }
};

static llvm::cl::OptionCategory ToolCategory(
    "dependency-extractor");

int main(int argc, const char **argv)
{
    auto ExpectedParser =
        CommonOptionsParser::create(argc, argv, ToolCategory);

    if (!ExpectedParser)
    {
        llvm::errs() << "Error parsing options\n";
        return 1;
    }

    CommonOptionsParser &optionsParser =
        ExpectedParser.get();

    ClangTool tool(
        optionsParser.getCompilations(),
        optionsParser.getSourcePathList());

    return tool.run(
        newFrontendActionFactory<DependencyAction>().get());
}