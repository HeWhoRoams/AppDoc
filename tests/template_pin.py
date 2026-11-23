"""Run the Check as the 2.4-era Check: the running template pinned to 2.4 (T27.29, strict C3)."""
from unittest import mock

from appdoc import template_spec as spec

STAMP_2_4 = "<!-- appdoc:template 2.4 -->"   # the template of AppDoc 2.4 to 2.6 (not the running template since 2.7.0)


def run_as_2_4(fn, *args, **kw):
    """Run `fn` (check.run or a call that ends in it) with the running template pinned to 2.4.

    Many tests were written when 2.4 was the running template and test one rule's logic on a 2.4-stamped document
    (the rule's behaviour below stamp 2.7, previews, 2.4 sections). Since 2.7.0 a 2.4 stamp is not the running
    template, so check.run fails such a document with the one C3 upgrade problem and runs no structure rule.
    Pinning the running version reproduces the situation those tests describe without weakening an assertion.
    The C3 upgrade failure itself is tested unpinned (test_check, test_upgrade, corpus `upgrade-2-6-to-2-7`).
    """
    with mock.patch.object(spec, "TEMPLATE_VERSION", "2.4"):
        return fn(*args, **kw)


def run_as_stamped(narrative: str, fn, *args, **kw):
    """`run_as_2_4` when the narrative text carries the 2.4 stamp, else a plain call (the real, strict Check)."""
    return run_as_2_4(fn, *args, **kw) if STAMP_2_4 in narrative else fn(*args, **kw)
