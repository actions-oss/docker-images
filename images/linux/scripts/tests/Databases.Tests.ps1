Describe "MongoDB" {
    It "<ToolName>" -TestCases @(
        @{ ToolName = "mongo" }
        @{ ToolName = "mongod" }
    ) {
        "$ToolName --version" | Should -ReturnZeroExitCode
    }
}

Describe "PostgreSQL" {

}

Describe "MySQL" {
    It "MySQL CLI" {
        "mysql -V" | Should -ReturnZeroExitCode
    }
}
