# Fyler Tests

### Running Tests

As a base requirement you must have `make` installed.

Once `make` is installed you can run tests by entering `make test` or `FYLER_DEBUG=1 make test` in the top level directory of Fyler into your command line.

### Tests filter

To run specific test case, set `FILTER` environment variable and run `make test` or combine both `FYLER=<test_case_name> make test`
