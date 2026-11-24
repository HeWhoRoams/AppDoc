"""Run the Check as an older template's Check: the running template pinned to an older version (strict C3).

Since 2.7.0 (and again since 2.8.0) only the running template is current: a document stamped older fails C3 with
the one upgrade problem and runs no structure rule. Many tests were written when 2.4 (or 2.7) was the running
template and test one rule's logic on a document of that template; pinning the running version reproduces that
situation without weakening an assertion. The C3 upgrade failure itself is tested unpinned (test_check,
test_core, corpus `upgrade-2-6-to-2-7` and `upgrade-2-7-to-2-8`).
"""
from unittest import mock

from appdoc import template_spec as spec

STAMP_2_4 = "<!-- appdoc:template 2.4 -->"   # the template of AppDoc 2.4 to 2.6
STAMP_2_7 = "<!-- appdoc:template 2.7 -->"   # the template of AppDoc 2.7.0 and 2.7.1 (not the running template since 2.8.0)


def run_as(version, fn, *args, **kw):
    """Run `fn` (check.run or a call that ends in it) with the running template pinned to `version` ("2.4", "2.7")."""
    with mock.patch.object(spec, "TEMPLATE_VERSION", version):
        return fn(*args, **kw)


def run_as_2_4(fn, *args, **kw):
    """`run_as("2.4", ...)`: the Check of AppDoc 2.4 to 2.6."""
    return run_as("2.4", fn, *args, **kw)


def run_as_2_7(fn, *args, **kw):
    """`run_as("2.7", ...)`: the Check of AppDoc 2.7 (the examples and the 2.7 test documents are stamped 2.7 until
    T28.C2 regenerates them on 2.8)."""
    return run_as("2.7", fn, *args, **kw)


def run_as_stamped(narrative: str, fn, *args, **kw):
    """The pin that matches the stamp the narrative text carries (2.4, then 2.7), else a plain call (the real, strict
    Check on the running template)."""
    if STAMP_2_4 in narrative:
        return run_as_2_4(fn, *args, **kw)
    if STAMP_2_7 in narrative:
        return run_as_2_7(fn, *args, **kw)
    return fn(*args, **kw)
