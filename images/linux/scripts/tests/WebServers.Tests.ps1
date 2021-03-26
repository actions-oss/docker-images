Describe "Apache" {
    It "Apache CLI" {
        "apache2 -v" | Should -ReturnZeroExitCode
    }
}

Describe "Nginx" {
    It "Nginx CLI" {
        "nginx -v" | Should -ReturnZeroExitCode
    }
}
