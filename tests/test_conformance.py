"""Stack conformance test (Phase 2.3): the "new language" guard.

For every stack in stacks.MODULES, run the extractor on its sample and assert:
  1. kind is in facts.KINDS
  2. path exists in the sample
  3. 1 <= line <= file length (when line is not None)
  4. detail keys are a subset of facts.DETAIL_KEYS[kind]
  5. no detail value has a secret shape
  6. two extractions are byte-identical
  7. the stack emits nothing outside its declared capabilities
  8. the sample exercises every declared capability, including entry_point subtypes
  9. every stack declares capabilities, the stack Fact records them, every emitted entry_point type is declared
"""

import importlib
import json
import os
import re
import shutil
import tempfile
import unittest

from appdoc import extract
from appdoc import fill
from appdoc import facts as facts_mod
from appdoc import secrets
from appdoc import stacks
from appdoc.stacks import MODULES, generic
from appdoc import summary
from tests.test_corpus import materialize_shared_target

SAMPLES = os.path.join(os.path.dirname(__file__), "samples")


# Kinds that stacks.generic.extract emits (it is not a registered Stack): exempt from per-stack capability checks.
# A literal on purpose: adding a generic kind must be a deliberate edit here and in generic.GENERIC_KINDS.
GENERIC_KINDS = frozenset({"build_define", "config_external", "config_key", "config_unparsed", "connection",
                           "context_directive", "dependency", "file", "owner_file", "project", "publish_profile",
                           "schema_object", "smell"})
# Generic kinds declared above that no reader emits yet; each leaves this set with the task that adds its reader.
# Capabilities written ``entry_point.<name>`` that name derived detail keys of the route entry points, not entry_point types.
DETAIL_CAPABILITIES = {"guard_mechanism": "guard_mechanism", "guard_reach": "reach"}   # capability -> the key that proves it
GENERIC_KINDS_NOT_YET_EMITTED = frozenset()   # every generic kind has its reader (config_external: T28.32)

# The Fact kinds 2.8.0 added to the 2.7 set (T28.C0); each is in KINDS and DETAIL_KEYS and falls under R18/R19.
NEW_2_8_KINDS = frozenset({
    "access_rule", "access_rule_unmatched", "antiforgery_check", "build_define", "conditional_const", "config_external",
    "config_transform", "config_unparsed", "const_def", "context_directive", "controller_class", "guard_candidate",
    "guard_class", "guard_use", "host_auth", "method_call", "mode_branch", "project", "publish_profile",
    "security_setting"})

_EMAIL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")
_SID = re.compile(r"\bS-1-\d+(?:-\d+)+")
_SCOPED_NPM = re.compile(r"@[a-z0-9][a-z0-9._-]*/[a-z0-9][a-z0-9._-]*")   # allow-listed: dependency names such as @types/node
_URL = re.compile(r"[A-Za-z][A-Za-z0-9+.-]*://[^\s\"'<>)\]`|]*")
_BARE_URL = re.compile(r"^[a-z][a-z0-9+.-]*://[^/@?#:\s]+(?::\d+)?$")   # scheme://host[:port], the only recorded URL shape (R19)
MVC5_ALL = "mvc5-classic+owin+core+webapi"


def _extract(sample_dir: str) -> dict:
    with tempfile.TemporaryDirectory() as out:
        text, _ = extract.extract(sample_dir, out)
    return json.loads(text)


class ConformanceTests(unittest.TestCase):
    """One test per stack, plus cross-cutting checks."""

    @classmethod
    def setUpClass(cls):
        cls.results = {}
        for name in MODULES:
            sample = os.path.join(SAMPLES, name.replace("_", "-"))
            if not os.path.isdir(sample):
                continue
            doc1 = _extract(sample)
            doc2 = _extract(sample)
            cls.results[name] = (sample, doc1, doc2)

    def _stack_name(self, module_name: str) -> str:
        """Map module name to the stack id used in facts."""
        import importlib
        mod = importlib.import_module(f"appdoc.stacks.{module_name}")
        return getattr(mod, "STACK_ID", module_name.replace("_", "-"))

    def _capabilities(self, module_name: str) -> frozenset:
        """Production's lookup (stacks.capabilities_of) on the registered instance, never the module."""
        import importlib
        mod = importlib.import_module(f"appdoc.stacks.{module_name}")
        return stacks.capabilities_of(mod.STACK)

    @staticmethod
    def _kinds_of(caps) -> set:
        """Fact kinds a capability set covers: ``entry_point.route`` covers ``entry_point``."""
        return {c.split(".", 1)[0] for c in caps}

    def test_all_stacks_have_samples(self):
        for name in MODULES:
            sample = os.path.join(SAMPLES, name.replace("_", "-"))
            self.assertTrue(os.path.isdir(sample), f"missing sample dir for {name}")

    def test_determinism(self):
        for name, (sample, doc1, doc2) in self.results.items():
            self.assertEqual(doc1, doc2, f"{name}: two extractions differ")

    def test_kind_in_kinds(self):
        for name, (sample, doc, _) in self.results.items():
            for f in doc["facts"]:
                self.assertIn(f["kind"], facts_mod.KINDS,
                              f"{name}: unknown kind {f['kind']!r} in {f['path']}")

    def test_path_exists(self):
        for name, (sample, doc, _) in self.results.items():
            for f in doc["facts"]:
                full = os.path.join(sample, f["path"].replace("/", os.sep))
                self.assertTrue(os.path.isfile(full),
                                f"{name}: path {f['path']!r} does not exist in sample")

    def test_line_in_range(self):
        for name, (sample, doc, _) in self.results.items():
            for f in doc["facts"]:
                if f["line"] is None:
                    continue
                full = os.path.join(sample, f["path"].replace("/", os.sep))
                with open(full, "rb") as fh:
                    nlines = fh.read().count(b"\n") + 1
                self.assertGreaterEqual(f["line"], 1,
                                        f"{name}: line < 1 in {f['path']}")
                self.assertLessEqual(f["line"], nlines,
                                     f"{name}: line {f['line']} > {nlines} in {f['path']}")

    def test_detail_keys_subset(self):
        for name, (sample, doc, _) in self.results.items():
            for f in doc["facts"]:
                allowed = facts_mod.DETAIL_KEYS.get(f["kind"], frozenset())
                for k in f.get("detail", {}):
                    self.assertIn(k, allowed,
                                  f"{name}: detail key {k!r} not in DETAIL_KEYS[{f['kind']!r}]")

    def test_no_secret_shapes(self):
        for name, (sample, doc, _) in self.results.items():
            for f in doc["facts"]:
                for k, v in f.get("detail", {}).items():
                    s = str(v)
                    shapes = secrets.find_secret_shapes(s)
                    self.assertEqual(shapes, [],
                                     f"{name}: secret shape in {f['kind']}.{k} = {s!r}")

    def test_no_facts_outside_capabilities(self):
        for name, (sample, doc, _) in self.results.items():
            caps = self._capabilities(name)
            if not caps:
                continue
            stack_id = self._stack_name(name)
            for f in doc["facts"]:
                if f["stack"] != stack_id:
                    continue
                self.assertIn(f["kind"], self._kinds_of(caps),
                              f"{name}: emits {f['kind']!r} not in capabilities {sorted(caps)}")

    def test_sample_exercises_every_capability(self):
        for name, (sample, doc, _) in self.results.items():
            caps = self._capabilities(name)
            if not caps:
                continue
            stack_id = self._stack_name(name)
            emitted = {f["kind"] for f in doc["facts"] if f["stack"] == stack_id}
            missing = self._kinds_of(caps) - emitted
            self.assertEqual(missing, set(),
                             f"{name}: capabilities {sorted(caps)} not exercised: {sorted(missing)}")
            subtypes = {f["detail"].get("type") for f in doc["facts"]
                        if f["stack"] == stack_id and f["kind"] == "entry_point"}
            declared = {c.split(".", 1)[1] for c in caps if c.startswith("entry_point.") and c.count(".") == 1}
            self.assertEqual(declared - set(DETAIL_CAPABILITIES) - subtypes, set(),
                             f"{name}: entry_point subtypes declared but not exercised by the sample")
            # a declared detail capability is exercised when some entry point of the stack carries the detail key
            for cap in sorted(declared & set(DETAIL_CAPABILITIES)):
                key = DETAIL_CAPABILITIES[cap]
                self.assertTrue(any(key in f["detail"] for f in doc["facts"]
                                    if f["stack"] == stack_id and f["kind"] == "entry_point"),
                                f"{name}: entry_point.{cap} declared but no entry point of the sample carries {key}")

    def test_supported_stack_declares_capabilities(self):
        for st in stacks.load():
            if not st.supported:
                continue
            caps = stacks.capabilities_of(st)
            self.assertIsInstance(caps, frozenset, st.id)
            self.assertTrue(caps, f"{st.id}: declares no capabilities")
            self.assertEqual(caps, st.capabilities, st.id)
            self.assertNotIn("entry_point", caps, f"{st.id}: bare entry_point; declare the subtypes")
            for c in caps:
                self.assertIn(c.split(".", 1)[0], facts_mod.KINDS, f"{st.id}: {c!r}")
            self.assertTrue(any(c.startswith("entry_point.") for c in caps), st.id)

    def test_no_guard_keys_without_capability(self):
        """W4 detail appears only on a Stack that declares it: the mechanism list on ``entry_point.guard_mechanism``, every
        other derived key (reach, URL set, verbs, writes) on ``entry_point.guard_reach``."""
        mech = {"guard_mechanism"}
        reach = {"reach", "reach_anon", "reach_auth", "reach_roles", "reach_by_config", "state_changing", "verbs",
                 "verbs_declared", "writes", "url_set"}
        for name, (sample, doc, _) in self.results.items():
            caps = self._capabilities(name)
            stack_id = self._stack_name(name)
            for f in doc["facts"]:
                if f["stack"] != stack_id or f["kind"] != "entry_point":
                    continue
                keys = set(f["detail"])
                if keys & mech:
                    self.assertIn("entry_point.guard_mechanism", caps, f"{name}: guard_mechanism without the capability")
                if keys & reach:
                    self.assertIn("entry_point.guard_reach", caps, f"{name}: {sorted(keys & reach)} without guard_reach")

    def test_every_entry_point_subtype_is_counted_or_listed_uncounted(self):
        known = set(fill.COUNTED_ENTRY_TYPES) | set(fill.UNCOUNTED_ENTRY_TYPES)
        self.assertFalse(set(fill.COUNTED_ENTRY_TYPES) & set(fill.UNCOUNTED_ENTRY_TYPES))
        for st in stacks.load():
            for cap in stacks.capabilities_of(st):
                if cap.startswith("entry_point.") and cap.split(".", 1)[1] not in DETAIL_CAPABILITIES:
                    self.assertIn(cap.split(".", 1)[1], known, f"{st.id}: {cap} is neither counted nor listed uncounted")

    def test_generic_kinds_exempt(self):
        emitted = set()
        targets = [os.path.join(SAMPLES, d) for d in sorted(os.listdir(SAMPLES))
                   if os.path.isdir(os.path.join(SAMPLES, d))]
        # a .NET project target (csproj, pubxml, a malformed project, context directives) has no stack sample
        targets.append(os.path.join(os.path.dirname(__file__), "fixtures", "dotnet-project"))
        for t in targets:
            emitted |= {f["kind"] for f in _extract(t)["facts"] if f["stack"] == "generic"}
        self.assertEqual(emitted, set(GENERIC_KINDS - GENERIC_KINDS_NOT_YET_EMITTED),
                         "generic.extract emits a kind the literal does not list (or the reverse)")
        self.assertEqual(generic.GENERIC_KINDS, GENERIC_KINDS)
        for name in MODULES:  # owner_file is the generic reader's alone
            self.assertNotIn("owner_file", self._kinds_of(self._capabilities(name)), name)

    def test_no_module_level_capability_alias(self):
        for name in MODULES:
            mod = importlib.import_module(f"appdoc.stacks.{name}")
            self.assertFalse(hasattr(mod, "capabilities"), f"{name}: module-level capabilities alias")

    def test_capabilities_of_takes_an_instance_only(self):
        st = stacks.load()[0]
        self.assertEqual(stacks.capabilities_of(st), st.capabilities)
        self.assertEqual(stacks.capabilities_of(object()), frozenset())

    def test_extract_records_capabilities(self):
        for name, (sample, doc, _) in self.results.items():
            stack_id = self._stack_name(name)
            recs = [s for s in doc["stacks"] if s["name"] == stack_id]
            self.assertEqual(len(recs), 1, f"{name}: expected one stack Fact for the sample")
            self.assertEqual(recs[0]["detail"]["capabilities"], sorted(self._capabilities(name)),
                             f"{name}: stack Fact differs from capabilities_of")

    def test_entry_point_type_needs_capability(self):
        for name, (sample, doc, _) in self.results.items():
            caps = self._capabilities(name)
            stack_id = self._stack_name(name)
            for f in doc["facts"]:
                if f["stack"] == stack_id and f["kind"] == "entry_point":
                    t = f["detail"].get("type")
                    self.assertIn(f"entry_point.{t}", caps,
                                  f"{name}: emits entry_point type {t!r} ({f['path']}:{f['line']}) without the capability")


def _mvc5(spec=MVC5_ALL, name="t", workers=0, use_cache=False, pad=0):
    """(doc, facts_text, summary_text) of the invented mvc5-classic Target with the given overlays, extracted in a temp folder."""
    with tempfile.TemporaryDirectory() as tmp:
        root = os.path.join(tmp, name)
        os.makedirs(root)
        materialize_shared_target(spec, root)
        for i in range(pad):   # cross PARALLEL_THRESHOLD so workers > 1 uses the pool
            with open(os.path.join(root, f"Pad{i}.txt"), "w") as fh:
                fh.write("x\n")
        text, summ = extract.extract(root, os.path.join(tmp, "out"), workers=workers, use_cache=use_cache,
                                     no_ownership=True)
        values = _secret_location_values(json.loads(text), root)
    return json.loads(text), text, summ, values


def _secret_location_values(doc: dict, root: str) -> set:
    """Quoted values on the source line of every secret_location Fact, plus ``Password=``/``Pwd=`` values (R19)."""
    values = set()
    for f in doc["facts"]:
        if f["kind"] in ("config_key", "connection") and f["detail"].get("secret_location"):
            p = os.path.join(root, *f["path"].split("/"))
            if not os.path.isfile(p):
                continue
            with open(p, encoding="utf-8-sig") as fh:
                line = fh.read().split("\n")[f["line"] - 1]
            attrs = re.findall(r'(?i)\b(value|connectionstring|password|pwd)="([^"]*)"', line)
            if attrs:   # an XML line: only the value-bearing attributes (not xdt:Transform, Locator, name)
                values |= {v for _, v in attrs}
            else:       # a source or JSON line: every quoted literal
                values |= {m for m in re.findall(r'"((?:[^"\\]|\\.)+)"', line)} - {f["name"]}
            values |= set(re.findall(r"(?i)\b(?:password|pwd)=([^;\"]+)", line))
    return {v for v in values if len(v) >= 8}


def _flat(f: dict) -> list:
    out = [f["name"]]
    for v in f.get("detail", {}).values():
        out += [str(x) for x in (v if isinstance(v, list) else [v])]
    return out


class NewKindHygieneTests(unittest.TestCase):
    """R18 and R19 over the 2.8 kinds and the generated blocks, on the invented mvc5-classic Target with every overlay."""

    @classmethod
    def setUpClass(cls):
        cls.doc, cls.text, cls.summary, cls.values = _mvc5()
        cls.blocks = {n: fill.generated_body(n, cls.doc, {"out_dir": None, "text": ""}) or ""
                      for n in fill.RENDERERS}
        cls.new_facts = [f for f in cls.doc["facts"] if f["kind"] in NEW_2_8_KINDS]

    def test_every_new_kind_is_in_kinds_and_detail_keys(self):
        for k in sorted(NEW_2_8_KINDS):
            self.assertIn(k, facts_mod.KINDS, k)
            self.assertTrue(facts_mod.DETAIL_KEYS.get(k), f"{k} has no DETAIL_KEYS")

    def test_generic_kinds_cover_the_generic_2_8_kinds(self):
        self.assertLessEqual({"project", "build_define", "publish_profile", "config_external", "config_unparsed",
                              "context_directive"}, GENERIC_KINDS)

    def test_aspnet_stacks_declare_capabilities(self):
        for name in ("aspnet", "aspnet_core"):
            self.assertTrue(os.path.isdir(os.path.join(SAMPLES, name.replace("_", "-"))), name)
            caps = stacks.capabilities_of(importlib.import_module(f"appdoc.stacks.{name}").STACK)
            self.assertTrue(caps, f"{name}: declares no capabilities")

    def test_the_target_exercises_the_new_kinds(self):
        emitted = {f["kind"] for f in self.new_facts}
        self.assertTrue({"guard_use", "const_def", "access_rule", "project", "publish_profile"} <= emitted, sorted(emitted))
        self.assertTrue(self.values, "the Target holds secret literals at secret locations")
        self.assertIn("not-a-real-credential-0001", self.values)
        self.assertIn("not-a-real-password-0004", self.values)

    def _assert_clean(self, text, where):
        text = _SCOPED_NPM.sub("", text)
        self.assertEqual(_EMAIL.findall(text), [], f"email-shaped text in {where}")
        self.assertEqual(_SID.findall(text), [], f"SID-shaped text in {where}")
        for v in self.values:
            self.assertNotIn(v, text, f"a secret_location value in {where}")

    def test_no_personal_identifiers_in_new_kinds(self):
        # the Target carries a role string shaped like an email and one shaped like a SID: both are counted, never recorded
        with open(os.path.join(materialize_shared_target_path(), "Contoso.Portal", "Controllers", "AdminController.cs"),
                  encoding="utf-8-sig") as fh:
            src = fh.read()
        self.assertRegex(src, _EMAIL)
        self.assertRegex(src, _SID)
        for f in self.new_facts:
            self._assert_clean(json.dumps(f, sort_keys=True), f"{f['kind']} {f['name']}")

    def test_no_personal_identifiers_in_blocks_and_summary(self):
        for name, body in self.blocks.items():
            self._assert_clean(body, f"block {name}")
        self._assert_clean(self.summary, "facts-summary.md")

    def test_no_auth_value_equals_secret_location(self):
        """R19: no Fact detail (or name) equals a value held at a secret_location, in the Target with every overlay."""
        self.assertTrue(self.values)
        for f in self.doc["facts"]:
            if f["kind"] in ("stack",):
                continue
            self.assertEqual(set(_flat(f)) & self.values, set(), f"{f['kind']} {f['name']}")

    def test_no_url_with_userinfo_path_or_query_in_new_kinds_or_blocks(self):
        def urls(text):
            return [u.rstrip(".,;") for u in _URL.findall(text)]
        for f in self.new_facts:
            for s in _flat(f):
                for u in urls(s):
                    self.assertRegex(u, _BARE_URL, f"{f['kind']} {f['name']}: {u!r}")
        for name, body in self.blocks.items():
            for u in urls(body):
                self.assertRegex(u, _BARE_URL, f"block {name}: {u!r}")

    def test_ownership_holds_counts_and_dates_only(self):
        for f in self.doc["facts"]:
            if f["kind"] == "ownership":
                self.assertLessEqual(set(f["detail"]), {"commits", "contributors", "first_commit", "last_commit"})


def materialize_shared_target_path():
    from tests.test_corpus import SHARED
    return os.path.join(SHARED, "mvc5-classic")


class MvcDeterminismTests(unittest.TestCase):
    """The mvc5-classic extract is byte-identical for --workers 0, --workers 4 and --no-cache (the Target name normalised)."""

    def _run(self, **kw):
        doc, text, summ, _ = _mvc5(MVC5_ALL, name="appdoc-target", pad=60, **kw)
        return text, summ

    def test_workers_0_4_and_no_cache_are_byte_identical(self):
        serial = self._run(workers=0, use_cache=True)
        pool = self._run(workers=4, use_cache=True)
        nocache = self._run(workers=0, use_cache=False)
        self.assertEqual(serial, pool)
        self.assertEqual(serial, nocache)

    def test_the_target_name_is_the_only_difference_between_two_folder_names(self):
        a = _mvc5(MVC5_ALL, name="alpha")[1]
        b = _mvc5(MVC5_ALL, name="beta")[1]
        self.assertEqual(a.replace("alpha", "@@"), b.replace("beta", "@@"))


if __name__ == "__main__":
    unittest.main()
