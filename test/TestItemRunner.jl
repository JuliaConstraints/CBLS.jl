using TestItemRunner

const _CBLS_TEST_ROOT = normpath(pkgdir(CBLS))
const _CBLS_TEST_TAGS = Set(Symbol(tag) for tag in
    filter(!isempty, strip.(split(get(ENV, "CBLS_TEST_TAGS", ""), ','))))

function _cbls_test_filter(testitem)
    filename = normpath(testitem.filename)
    belongs_to_cbls = filename == _CBLS_TEST_ROOT ||
                      startswith(filename, _CBLS_TEST_ROOT * Base.Filesystem.path_separator)
    selected = isempty(_CBLS_TEST_TAGS) ||
               any(tag -> tag in _CBLS_TEST_TAGS, testitem.tags)
    return belongs_to_cbls && selected
end

@testset "TestItemRunner" begin
    @run_package_tests filter = _cbls_test_filter
end
