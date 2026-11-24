"""appdoc/configs.py: build configurations, the transform engine, effective values, overridden_in (W1, R17)."""
import json
import os
import tempfile
import unittest

from appdoc import configs, context, extract
from appdoc import dotnetsec as S
from tests.test_dotnetsec import GLOBAL, cfg, of, run

XDT = 'xmlns:xdt="http://schemas.microsoft.com/XML-Document-Transform"'


def transform(body: str) -> str:
    return f'<?xml version="1.0"?>\n<configuration {XDT}>\n{body}\n</configuration>\n'


BASE = cfg("""<appSettings><add key="Env" value="base" /><add key="Other" value="1" /></appSettings>
<connectionStrings><add name="Db" connectionString="Server=a;Integrated Security=SSPI" /></connectionStrings>
<system.web>
  <authentication mode="Windows" />
  <authorization><allow roles="A" /><allow roles="B" /><deny users="*" /></authorization>
  <customErrors mode="Off" />
  <compilation debug="true" />
  <httpCookies requireSSL="false" httpOnlyCookies="true" />
  <trace enabled="true" localOnly="true" />
</system.web>
<location path="Billing"><system.web><authorization><allow roles="Fin" /><deny users="*" /></authorization></system.web></location>""")


def target(**transforms):
    files = dict(GLOBAL)
    files["Web.config"] = BASE
    for name, body in transforms.items():
        files[f"Web.{name}.config"] = transform(body)
    return files


def setting(doc, name, config, path="Web.config"):
    got = [f["detail"] for f in of(doc, "security_setting", name=name, config=config) if f["path"] == path]
    assert len(got) == 1, (name, config, got)
    return got[0]


def rules(doc, config, scope=""):
    got = [f["detail"] for f in of(doc, "access_rule", config=config) if f["detail"]["scope_path"] == scope
           and f["path"] == "Web.config"]
    return sorted(got, key=lambda d: d["order"])


class ConfigurationSetTests(unittest.TestCase):
    def test_configurations_function(self):
        self.assertEqual(configs.configurations(["release", "Staging"], ["Release", "QA"], ["debug", "Staging"]),
                         ["debug", "QA", "release", "Staging"], "first spelling wins, sorted case-insensitively")
        self.assertEqual(configs.configurations([]), [])

    def test_configurations_from_transforms_csproj_sln(self):
        files = target(Release='<system.web><compilation xdt:Transform="RemoveAttributes(debug)" /></system.web>')
        files["App.csproj"] = ('<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'
                               '<PropertyGroup Condition=" \'$(Configuration)|$(Platform)\' == \'Staging|AnyCPU\' "><DebugType>full</DebugType></PropertyGroup>'
                               '<PropertyGroup Condition=" \'$(Configuration)|$(Platform)\' == \'Release|AnyCPU\' "><DefineConstants>TRACE</DefineConstants></PropertyGroup>'
                               '</Project>')
        files["All.sln"] = ('Global\n\tGlobalSection(SolutionConfigurationPlatforms) = preSolution\n'
                            '\t\tDebug|Any CPU = Debug|Any CPU\n\t\tQA|Any CPU = QA|Any CPU\n\t\tRelease|Any CPU = Release|Any CPU\n'
                            '\tEndGlobalSection\nEndGlobal\n')
        doc = run(files)
        got = sorted({f["detail"]["config"] for f in of(doc, "security_setting") if f["path"] == "Web.config"})
        self.assertEqual(got, ["Debug", "QA", "Release", "Staging", "base"])

    def test_config_without_transform_is_base(self):
        files = dict(target(Release='<system.web><compilation xdt:Transform="RemoveAttributes(debug)" /></system.web>'))
        files["All.sln"] = ('GlobalSection(SolutionConfigurationPlatforms) = preSolution\n\t\tTraining|Any CPU = Training|Any CPU\n'
                            '\t\tRelease|Any CPU = Release|Any CPU\nEndGlobalSection\n')
        doc = run(files)
        d = setting(doc, "system.web/compilation@debug", "Training")
        self.assertEqual((d["value"], d["config_status"]), ("true", "base"))
        self.assertEqual(setting(doc, "system.web/compilation@debug", "Release")["config_status"], "transformed")

    def test_debug_config_computed_like_any_other(self):
        doc = run(target(Debug='<system.web><compilation xdt:Transform="SetAttributes" debug="true" /></system.web>',
                         Release='<system.web><compilation xdt:Transform="RemoveAttributes(debug)" /></system.web>'))
        self.assertEqual(setting(doc, "system.web/compilation@debug", "Debug")["config_status"], "transformed")
        self.assertEqual(setting(doc, "system.web/compilation@debug", "Debug")["value"], "true")

    def test_transform_file_alone_not_a_configuration(self):
        files = {**GLOBAL, "Web.Release.config": transform('<system.web><compilation xdt:Transform="RemoveAttributes(debug)" /></system.web>')}
        doc = run(files)
        self.assertEqual(of(doc, "security_setting"), [], "no Web.config: nothing to apply a transform to")
        self.assertEqual(of(doc, "access_rule"), [])
        self.assertTrue(of(doc, "config_transform", config="Release"), "the transform itself is still recorded")

    def test_nested_webconfig_no_transform(self):
        files = target(Release='<system.web><compilation xdt:Transform="RemoveAttributes(debug)" /></system.web>')
        files["Admin/Web.config"] = cfg('<system.web><compilation debug="true" /><authorization><allow roles="x" /></authorization></system.web>')
        files["Admin/Web.Release.config"] = transform('<system.web><compilation xdt:Transform="RemoveAttributes(debug)" /></system.web>')
        doc = run(files)
        nested = [f for f in of(doc, "security_setting") if f["path"] == "Admin/Web.config"]
        self.assertEqual({f["detail"]["config"] for f in nested}, {"base"}, "a nested Web.config gets no transform")
        self.assertEqual([f["name"] for f in nested], ["system.web/compilation@debug"], "present values only: absent is inherited")
        self.assertEqual({f["detail"]["config"] for f in of(doc, "access_rule") if f["path"] == "Admin/Web.config"}, {"base"})

    def test_projectconfigtransformfilename_makes_lookup_unknown(self):
        files = target(Release='<system.web><compilation xdt:Transform="RemoveAttributes(debug)" /></system.web>')
        files["App.csproj"] = ('<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003"><PropertyGroup>'
                               '<ProjectConfigTransformFileName>Custom.config</ProjectConfigTransformFileName></PropertyGroup></Project>')
        doc = run(files)
        d = setting(doc, "system.web/compilation@debug", "Release")
        self.assertEqual((d["value"], d["config_status"]), ("unknown", "unknown_transform"))
        self.assertEqual(setting(doc, "system.web/compilation@debug", "base")["value"], "true", "the base is untouched")
        self.assertTrue(all(r["config_status"] == "unknown_transform" for r in rules(doc, "Release")))

    def test_production_config_default_and_directive(self):
        self.assertEqual(configs.production_config([]), "Release")
        ctx = context.parse("Production config: Live\n")
        facts = [extract.F.Fact.make("context_directive", "generic", "appdoc-context.md", d.line, d.name,
                                     directive=d.key, value=d.value) for d in context.directives(ctx)]
        self.assertEqual(configs.production_config(facts), "Live")


class TransformEngineTests(unittest.TestCase):
    def test_transform_release_sets_customerrors(self):
        doc = run(target(Release='<system.web><customErrors defaultRedirect="~/Err" mode="RemoteOnly" xdt:Transform="SetAttributes" /></system.web>'))
        d = setting(doc, "system.web/customErrors@mode", "Release")
        self.assertEqual((d["value"], d["config_status"]), ("remoteonly", "transformed"))
        self.assertEqual(setting(doc, "system.web/customErrors@mode", "base")["value"], "off", "R17: the base is never overwritten")

    def test_transform_remove_debug(self):
        doc = run(target(Release='<system.web><compilation xdt:Transform="RemoveAttributes(debug)" /></system.web>',
                         Staging='<system.web><compilation xdt:Transform="Remove" /></system.web>'))
        for c in ("Release", "Staging"):
            self.assertEqual(setting(doc, "system.web/compilation@debug", c)["value"], "absent", c)

    def test_setattributes_no_arglist(self):
        doc = run(target(Release='<system.web><httpCookies requireSSL="true" httpOnlyCookies="false" xdt:Transform="SetAttributes" /></system.web>',
                         Staging='<system.web><httpCookies requireSSL="true" httpOnlyCookies="false" xdt:Transform="SetAttributes(requireSSL)" /></system.web>'))
        self.assertEqual([setting(doc, f"system.web/httpCookies@{a}", "Release")["value"] for a in ("requireSSL", "httpOnlyCookies")],
                         ["true", "false"], "without an attribute list every attribute is set")
        self.assertEqual([setting(doc, f"system.web/httpCookies@{a}", "Staging")["value"] for a in ("requireSSL", "httpOnlyCookies")],
                         ["true", "true"], "with a list only the listed ones")

    def test_removeall_no_locator(self):
        doc = run(target(Release='<system.web><trace xdt:Transform="RemoveAll" /></system.web>'))
        d = setting(doc, "system.web/trace@enabled", "Release")
        self.assertEqual((d["value"], d["config_status"]), ("absent", "transformed"))
        self.assertNotIn("local_only", d)

    def test_insert_appends_after_existing_rules(self):
        doc = run(target(Release='<location path="Billing" xdt:Locator="Match(path)"><system.web><authorization>'
                                 '<allow roles="Interns" xdt:Transform="Insert" /></authorization></system.web></location>'
                                 '<system.web><authorization><deny users="?" xdt:Transform="Insert" /></authorization></system.web>'))
        got = rules(doc, "Release", "Billing")
        self.assertEqual([(d["effect"], d.get("roles")) for d in got], [("allow", ["Fin"]), ("deny", None), ("allow", ["Interns"])],
                         "the inserted rule lands after existing rules, including after deny *")
        self.assertEqual([d["order"] for d in got], sorted(d["order"] for d in got))
        root = rules(doc, "Release")
        self.assertEqual([d["effect"] for d in root], ["allow", "allow", "deny", "deny"])
        self.assertTrue(all(d["config_status"] == "transformed" for d in got + root))
        self.assertEqual([d["config_status"] for d in rules(doc, "base", "Billing")], ["base", "base"])

    def test_replace_first_match_only(self):
        doc = run(target(Release='<system.web><authorization><allow roles="New" xdt:Transform="Replace" /></authorization></system.web>'))
        got = rules(doc, "Release")
        self.assertEqual([(d["effect"], d.get("roles")) for d in got], [("allow", ["New"]), ("allow", ["B"]), ("deny", None)])

    def test_remove_first_and_removeall_by_name(self):
        doc = run(target(Release='<system.web><authorization><allow xdt:Transform="Remove" /></authorization></system.web>',
                         Staging='<system.web><authorization><allow xdt:Transform="RemoveAll" /></authorization></system.web>'))
        self.assertEqual([(d["effect"], d.get("roles")) for d in rules(doc, "Release")], [("allow", ["B"]), ("deny", None)])
        self.assertEqual([d["effect"] for d in rules(doc, "Staging")], ["deny"])

    def test_setattributes_on_a_rule(self):
        doc = run(target(Release='<system.web><authorization><allow roles="Z" xdt:Transform="SetAttributes" /></authorization></system.web>'))
        self.assertEqual([(d["effect"], d.get("roles")) for d in rules(doc, "Release")],
                         [("allow", ["Z"]), ("allow", ["B"]), ("deny", None)])

    def test_unsupported_transform_makes_effective_unknown(self):
        doc = run(target(Odd='<system.web><authorization xdt:Transform="Replace" xdt:Locator="XPath(/configuration/system.web/authorization)">'
                             '<allow roles="x" /></authorization><compilation xdt:Transform="Replace" xdt:Locator="Match(debug)" debug="false" /></system.web>'))
        for d in rules(doc, "Odd"):
            self.assertEqual(d["config_status"], "unknown_transform")
        c = setting(doc, "system.web/compilation@debug", "Odd")
        self.assertEqual((c["value"], c["config_status"]), ("unknown", "unknown_transform"), "never the base value")
        self.assertEqual(setting(doc, "system.web/customErrors@mode", "Odd")["config_status"], "base", "an untouched setting is the base")
        self.assertEqual({d["config_status"] for d in rules(doc, "Odd", "Billing")}, {"base"})
        t = {f["name"]: f["detail"] for f in of(doc, "config_transform", config="Odd")}
        self.assertEqual({d["unsupported_reason"] for d in t.values()}, {"xpath", "locator_on_security_element"})

    def test_insertbefore_after_unknown(self):
        doc = run(target(Odd='<system.web><authorization><allow roles="x" xdt:Transform="InsertAfter(/configuration/system.web/authorization/allow[1])" /></authorization>'
                             '<customErrors mode="On" xdt:Transform="InsertBefore(/configuration/system.web/compilation)" /></system.web>'))
        for d in rules(doc, "Odd"):
            self.assertEqual(d["config_status"], "unknown_transform")
        self.assertEqual(setting(doc, "system.web/customErrors@mode", "Odd")["value"], "unknown")
        ops = {f["detail"]["operation"]: f["detail"] for f in of(doc, "config_transform", config="Odd")}
        self.assertEqual({k: (v["recognised"], v["supported"]) for k, v in ops.items()},
                         {"InsertAfter": (True, False), "InsertBefore": (True, False)})

    def test_insertifmissing_and_unknown_operation_are_unsupported(self):
        doc = run(target(Odd='<system.web><compilation debug="false" xdt:Transform="InsertIfMissing" />'
                             '<customErrors mode="On" xdt:Transform="Frobnicate" /></system.web>'))
        ops = {f["detail"]["operation"]: f["detail"] for f in of(doc, "config_transform", config="Odd")}
        self.assertEqual((ops["InsertIfMissing"]["recognised"], ops["InsertIfMissing"]["supported"]), (True, False))
        self.assertEqual((ops["Frobnicate"]["recognised"], ops["Frobnicate"]["supported"]), (False, False))

    def test_xdt_namespace_not_prefix(self):
        text = ('<?xml version="1.0"?>\n<configuration xmlns:q="https://schemas.microsoft.com/XML-Document-Transform">\n'
                '<system.web><compilation q:Transform="RemoveAttributes(debug)" /></system.web>\n</configuration>\n')
        files = target()
        files["Web.Release.config"] = text
        self.assertEqual(setting(run(files), "system.web/compilation@debug", "Release")["value"], "absent")

    def test_transform_facts_carry_no_secret_value(self):
        files = target(Release='<system.web><identity password="not-a-real-pw-11" userName="svc" xdt:Transform="Replace" />'
                               '<machineKey validationKey="0123456789ABCDEF0123456789ABCDEF" xdt:Transform="Replace" /></system.web>')
        doc = run(files)
        blob = json.dumps([f for f in doc["facts"] if f["kind"] in ("config_transform", "security_setting")])
        for leak in ("not-a-real-pw", "0123456789ABCDEF", "svc"):
            self.assertNotIn(leak, blob)
        d = setting(doc, "system.web/identity@password", "Release")
        self.assertEqual((d["value"], d["secret_location"]), ("other", True))
        mk = setting(doc, "system.web/machineKey", "Release")
        self.assertEqual((mk["value"], mk["secret_location"]), ("literal_hex", True))

    def test_replace_of_a_parent_element(self):
        doc = run(target(Release='<system.web xdt:Transform="Replace"><authentication mode="Forms" /><authorization><deny users="?" /></authorization></system.web>'))
        self.assertEqual(setting(doc, "system.web/authentication@mode", "Release")["value"], "forms")
        self.assertEqual(setting(doc, "system.web/compilation@debug", "Release")["value"], "absent")
        self.assertEqual([d["effect"] for d in rules(doc, "Release")], ["deny"])

    def test_insert_of_a_present_element_is_unknown(self):
        doc = run(target(Release='<system.web><compilation debug="false" xdt:Transform="Insert" /></system.web>'))
        d = setting(doc, "system.web/compilation@debug", "Release")
        self.assertEqual((d["value"], d["config_status"]), ("unknown", "unknown_transform"))

    def test_malformed_transform_file_makes_the_configuration_unknown(self):
        files = target()
        files["Web.Release.config"] = "<configuration><system.web><compilation"
        doc = run(files)
        self.assertEqual(setting(doc, "system.web/compilation@debug", "Release")["config_status"], "unknown_transform")
        self.assertEqual([f["detail"]["reason"] for f in of(doc, "config_unparsed")], ["malformed"])

    def test_apply_transforms_does_not_change_its_inputs(self):
        settings = {"system.web/compilation@debug": ("true", 5)}
        rules_in = [{"effect": "allow", "roles": ["a"], "anon": False, "all": False, "users_named": 0, "verbs": [],
                     "domain": False, "line": 3, "file": "Web.config", "loc": None, "keep": {}}]
        t = [{"target_path": "system.web/compilation", "operation": "Remove", "supported": True, "line": 1, "file": "W.R.config"}]
        eff, out, status = configs.apply_transforms(settings, rules_in, t)
        self.assertEqual(eff["system.web/compilation@debug"][:3], ("absent", 5, "transformed"))
        self.assertEqual(settings, {"system.web/compilation@debug": ("true", 5)})
        self.assertEqual(out, rules_in)


class OverriddenInTests(unittest.TestCase):
    FILES = target(
        Debug='<appSettings><add key="Env" value="dbg" xdt:Transform="SetAttributes" xdt:Locator="Match(key)" /></appSettings>',
        Release='<appSettings><add key="Env" value="rel" xdt:Transform="SetAttributes" xdt:Locator="Match(key)" />'
                '<add key="New" value="x" xdt:Transform="Insert" /></appSettings>'
                '<connectionStrings><add name="Db" connectionString="Server=prod" xdt:Transform="Replace" xdt:Locator="Match(name)" /></connectionStrings>',
        Staging='<appSettings><add key="Env" xdt:Transform="Remove" xdt:Locator="Condition(@key=\'Env\')" /></appSettings>')

    def test_overridden_in_recorded(self):
        doc = run(self.FILES)
        env = [f for f in of(doc, "config_key") if f["path"] == "Web.config" and f["name"] == "Env"][0]
        self.assertEqual(env["detail"]["overridden_in"], ["Debug", "Release", "Staging"])
        db = [f for f in of(doc, "connection") if f["path"] == "Web.config" and f["name"] == "Db"][0]
        self.assertEqual(db["detail"]["overridden_in"], ["Release"])

    def test_overridden_in_keys_no_values(self):
        doc = run(self.FILES)
        other = [f for f in of(doc, "config_key") if f["path"] == "Web.config" and f["name"] == "Other"][0]
        self.assertNotIn("overridden_in", other["detail"], "a key no transform touches")
        new = [f for f in of(doc, "config_key") if f["name"] == "New" and f["path"] == "Web.config"]
        self.assertEqual(new, [], "an Insert of a new key overrides nothing in the base")
        blob = json.dumps([f["detail"] for f in of(doc, "config_key") + of(doc, "connection") if f["path"] == "Web.config"])
        for leak in ("dbg", "rel", "Server=prod"):
            self.assertNotIn(leak, blob)


class DeterminismTests(unittest.TestCase):
    def test_effective_facts_serial_pool_cache_identical(self):
        files = target(Release='<system.web><compilation xdt:Transform="RemoveAttributes(debug)" /></system.web>',
                       Odd='<system.web><authorization xdt:Transform="Replace" xdt:Locator="XPath(/x)" /></system.web>')
        for i in range(60):
            files[f"Filler/Page{i}.aspx"] = '<%@ Page Language="C#" %>\n<html></html>\n'
        with tempfile.TemporaryDirectory() as tmp:
            root = os.path.join(tmp, "t")
            for rel, text in files.items():
                full = os.path.join(root, *rel.split("/"))
                os.makedirs(os.path.dirname(full), exist_ok=True)
                with open(full, "w", encoding="utf-8", newline="\n") as fh:
                    fh.write(text)
            serial, _ = extract.extract(root, os.path.join(tmp, "o1"), workers=0, use_cache=False, no_ownership=True)
            pool, _ = extract.extract(root, os.path.join(tmp, "o2"), workers=2, use_cache=False, no_ownership=True)
            cold, _ = extract.extract(root, os.path.join(tmp, "o3"), workers=0, use_cache=True, no_ownership=True)
            warm, _ = extract.extract(root, os.path.join(tmp, "o3"), workers=0, use_cache=True, no_ownership=True)
        self.assertEqual(serial, pool)
        self.assertEqual(serial, cold)
        self.assertEqual(serial, warm)
        self.assertIn('"config_status": "transformed"', serial)


if __name__ == "__main__":
    unittest.main()
