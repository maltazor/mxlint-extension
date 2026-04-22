.PHONY: all clean frontend rebuild

all: rebuild

clean:
	dotnet clean MxLintExtension.sln /p:Configuration=Debug /p:Platform="Any CPU"
	rm -rf bin obj tests/MxLintExtension.Tests/bin tests/MxLintExtension.Tests/obj

frontend:
	cd frontend && npm install
	cd frontend && npm run build
	rm -f wwwroot/index.html wwwroot/index-*.css wwwroot/index-*.js
	cp -r frontend/dist/* wwwroot/

rebuild: clean frontend
	dotnet build MxLintExtension.sln --no-incremental /property:GenerateFullPaths=true /consoleloggerparameters:NoSummary /p:Configuration=Debug /p:Platform="Any CPU"
	rm -rf resources/App/extensions/MxLintExtension/*
	cp -r bin/Debug/net8.0/* resources/App/extensions/MxLintExtension/