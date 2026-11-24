"""appdoc/dotnetsec.py: per-file .NET security settings, access rules, WCF endpoints and host disclosure (W1, W2)."""
import json
import os
import tempfile
import unittest

from appdoc import dotnetsec as S, extract, summary


def facts(path, text, kind=None):
    out = [f for f in S.config_facts(path, text) if kind is None or f.kind == kind]
    return out


def one(path, text, kind, name):
    got = [f for f in facts(path, text, kind) if f.name == name]
    assert len(got) == 1, (name, got)
    return got[0]


def val(path, text, name):
    return one(path, text, "security_setting", name).detail_dict()


def cfg(body: str) -> str:
    return f'<?xml version="1.0" encoding="utf-8"?>\n<configuration>\n{body}\n</configuration>\n'


def run(files, **kw):
    """Write ``files`` to a temp Target, run the whole extraction, return the Facts document."""
    with tempfile.TemporaryDirectory() as tmp:
        root = os.path.join(tmp, "t")
        for rel, text in files.items():
            full = os.path.join(root, *rel.split("/"))
            os.makedirs(os.path.dirname(full), exist_ok=True)
            data = text if isinstance(text, bytes) else text.encode("utf-8")
            with open(full, "wb") as fh:
                fh.write(data)
        text, _ = extract.extract(root, os.path.join(tmp, "out"), workers=0, use_cache=False, no_ownership=True, **kw)
    return json.loads(text)


def of(doc, kind, **detail):
    return [f for f in doc["facts"] if f["kind"] == kind
            and all(f["detail"].get(k) == v for k, v in detail.items())]


GLOBAL = {"Global.asax": '<%@ Application Codebehind="Global.asax.cs" Inherits="Contoso.A.App" %>'}


class SettingsTests(unittest.TestCase):
    def test_system_web_settings(self):
        text = cfg("""<system.web>
  <authentication mode="Forms"><forms requireSSL="true" /></authentication>
  <customErrors mode="RemoteOnly" />
  <compilation debug="false" />
  <httpCookies requireSSL="TRUE" httpOnlyCookies="false" />
  <sessionState mode="SQLServer" cookieless="UseUri" />
  <httpRuntime requestValidationMode="4.5" />
  <identity impersonate="true" />
</system.web>
<system.webServer><httpErrors errorMode="Detailed" /></system.webServer>""")
        want = {"system.web/authentication@mode": "forms", "system.web/forms@requireSSL": "true",
                "system.web/customErrors@mode": "remoteonly", "system.web/compilation@debug": "false",
                "system.web/httpCookies@requireSSL": "true", "system.web/httpCookies@httpOnlyCookies": "false",
                "system.web/sessionState@mode": "sqlserver", "system.web/sessionState@cookieless": "useuri",
                "system.web/httpRuntime@requestValidationMode": "4.5", "system.web/identity@impersonate": "true",
                "system.webServer/httpErrors@errorMode": "detailed"}
        for name, value in want.items():
            d = val("Web.config", text, name)
            self.assertEqual((d["value"], d["config"], d["config_status"]), (value, "base", "base"), name)
            self.assertEqual(d["name"], name, "the name is also a detail, as the corpus cases read it")

    def test_value_outside_the_enumeration_is_other(self):
        d = val("Web.config", cfg('<system.web><customErrors mode="Whatever-3f9a" /></system.web>'),
                "system.web/customErrors@mode")
        self.assertEqual(d["value"], "other")

    def test_missing_element_is_absent_not_default(self):
        text = cfg('<system.web>\n<compilation targetFramework="4.8" />\n</system.web>')
        for name in ("system.web/compilation@debug", "system.web/customErrors@mode", "system.web/authentication@mode",
                     "system.web/machineKey", "system.web/httpCookies@requireSSL"):
            self.assertEqual(val("Web.config", text, name)["value"], "absent", name)
        # the line of an absent attribute is the element's, of an absent element the nearest present parent's
        self.assertEqual(one("Web.config", text, "security_setting", "system.web/compilation@debug").line, 4)
        self.assertEqual(one("Web.config", text, "security_setting", "system.web/customErrors@mode").line, 3)
        # no framework default is ever written: the removed-element case is not "off"
        self.assertNotIn("off", {val("Web.config", text, n)["value"] for n in
                                 ("system.web/customErrors@mode", "system.web/compilation@debug")})

    def test_machinekey_classes(self):
        hexkey = "0123456789ABCDEF" * 2
        cases = {
            '<machineKey validationKey="AutoGenerate,IsolateApps" decryptionKey="AutoGenerate,IsolateApps" />': "autogenerate",
            f'<machineKey validationKey="{hexkey}" decryptionKey="{hexkey}" />': "literal_hex",
            '<machineKey validationKey="#{ValKey}" decryptionKey="${DecKey}" />': "placeholder",
            '<machineKey validationKey="$(ValKey)" decryptionKey="__DecKey__" />': "placeholder",
            '<machineKey validation="SHA1" />': "absent_keys",
            '<machineKey validationKey="not-hex-at-all" decryptionKey="AutoGenerate" />': "other",
        }
        for xml, want in cases.items():
            d = val("Web.config", cfg(f"<system.web>{xml}</system.web>"), "system.web/machineKey")
            self.assertEqual(d["value"], want, xml)
            self.assertEqual(d["secret_location"], want == "literal_hex", "only literal_hex is a secret location")

    def test_machinekey_literal_no_value(self):
        hexkey = "FEDCBA9876543210" * 4
        fs = facts("Web.config", cfg(f'<system.web><machineKey validationKey="{hexkey}" decryptionKey="{hexkey[:32]}" /></system.web>'))
        self.assertTrue(fs)
        self.assertNotIn(hexkey[:32], json.dumps([f.to_json() for f in fs]))

    def test_trace_local_only_recorded(self):
        d = val("Web.config", cfg('<system.web><trace enabled="true" localOnly="false" /></system.web>'),
                "system.web/trace@enabled")
        self.assertEqual((d["value"], d["local_only"]), ("true", False))
        d = val("Web.config", cfg('<system.web><trace enabled="true" /></system.web>'), "system.web/trace@enabled")
        self.assertNotIn("local_only", d, "an absent localOnly is not the framework default")
        names = [f.name for f in facts("Web.config", cfg("<system.web />"), "security_setting")]
        self.assertNotIn("system.web/trace@localOnly", names, "folded into trace@enabled")

    def test_settings_outside_web_config_are_present_only(self):
        fs = facts("App.config", cfg('<system.web><compilation debug="true" /></system.web>'), "security_setting")
        self.assertEqual([f.name for f in fs], ["system.web/compilation@debug"], "an app.config records no absences")

    def test_secret_carriers_no_value(self):
        text = cfg("""<system.web>
  <identity impersonate="true" userName="svc-demo" password="not-a-real-pw-1" />
  <sessionState mode="SQLServer" sqlConnectionString="Data Source=x;User ID=u;Password=not-a-real-pw-2" />
  <processModel userName="machine" password="#{ProcPw}" />
  <authentication mode="Forms"><forms><credentials passwordFormat="Clear"><user name="a" password="not-a-real-pw-3" /></credentials></forms></authentication>
</system.web>
<system.net><mailSettings><smtp><network host="h" password="not-a-real-pw-4" /></smtp></mailSettings></system.net>
<connectionStrings>
  <add name="A" connectionString="Server=s;User ID=u;Password=not-a-real-pw-5;" />
  <add name="B" connectionString="Server=s;Integrated Security=SSPI;" />
  <add name="C" connectionString="Server=s;Password=#{DbPw};" />
  <add name="D" connectionString="Server=s;UID=bob;" />
</connectionStrings>""")
        for name in ("system.web/identity@password", "system.web/sessionState@sqlConnectionString",
                     "system.net/mailSettings/smtp/network@password"):
            d = val("Web.config", text, name)
            self.assertEqual((d["value"], d["secret_location"]), ("other", True), name)
        self.assertEqual(val("Web.config", text, "system.web/forms/credentials")["value"], "literal")
        self.assertTrue(val("Web.config", text, "system.web/forms/credentials")["secret_location"])
        pm = val("Web.config", text, "system.web/processModel@password")
        self.assertEqual((pm["value"], pm["secret_location"]), ("placeholder", False))
        self.assertFalse(val("Web.config", text, "system.web/identity@userName")["secret_location"])
        cs = val("Web.config", text, "connectionStrings/add@connectionString")
        self.assertEqual((cs["count"], cs["secret_location"]), (2, True), "connection strings A and D carry a literal credential")
        blob = json.dumps([f.to_json() for f in facts("Web.config", text)])
        for leak in ("not-a-real-pw", "svc-demo", "bob"):
            self.assertNotIn(leak, blob)

    def test_credential_count_is_taken_in_transform_files_too(self):
        text = cfg('<connectionStrings><add name="A" connectionString="Server=s;Password=not-a-real-pw-9;" /></connectionStrings>')
        d = val("Web.Release.config", text, "connectionStrings/add@connectionString")
        self.assertEqual((d["config"], d["count"]), ("Release", 1))

    def test_wcf_endpoint_no_userinfo(self):
        text = cfg("""<system.serviceModel><client>
  <endpoint address="https://svc:not-a-real-pw@Reports.Contoso.test:8443/Svc.svc?token=abc#f" binding="basicHttpBinding" contract="Contoso.IReport" name="ReportEndpoint" />
  <endpoint address="net.tcp://backend.contoso.test/Svc" contract="Contoso.IBack" name="Back" />
  <endpoint address="relative/only" contract="Contoso.IRel" name="Rel" />
</client></system.serviceModel>""")
        calls = facts("Web.config", text, "external_call")
        self.assertEqual(sorted(f.name for f in calls), ["https://reports.contoso.test:8443", "net.tcp://backend.contoso.test"])
        first = next(f for f in calls if f.name.startswith("https"))
        self.assertEqual(first.detail_dict(), {"type": "service", "via": "Contoso.IReport", "config_key": "ReportEndpoint"})
        blob = json.dumps([f.to_json() for f in calls])
        for leak in ("not-a-real-pw", "token", "Svc.svc", "svc:"):
            self.assertNotIn(leak, blob)

    def test_wcf_client_credentials_secret_location(self):
        text = cfg("""<system.serviceModel><behaviors><endpointBehaviors><behavior name="b">
  <clientCredentials><userName userName="u1" password="not-a-real-pw-7" /></clientCredentials>
</behavior></endpointBehaviors></behaviors></system.serviceModel>""")
        d = val("Web.config", text, "system.serviceModel/clientCredentials")
        self.assertTrue(d["secret_location"])
        self.assertNotIn("not-a-real-pw", json.dumps([f.to_json() for f in facts("Web.config", text)]))


class ExternalTests(unittest.TestCase):
    def test_config_source_resolved(self):
        files = dict(GLOBAL)
        files["Web.config"] = cfg('<system.web><compilation configSource="compilation.config" /></system.web>')
        files["compilation.config"] = '<?xml version="1.0"?>\n<compilation debug="true" />\n'
        doc = run(files)
        ext = of(doc, "config_external")
        self.assertEqual([(f["path"], f["name"]) for f in ext], [("Web.config", "system.web/compilation@configSource")])
        self.assertEqual((ext[0]["detail"]["resolved"], ext[0]["detail"]["target"]), (True, "compilation.config"))
        dbg = [f for f in of(doc, "security_setting", name="system.web/compilation@debug", config="base")
               if f["path"] == "Web.config"]
        self.assertEqual(dbg[0]["detail"]["value"], "true", "the external section file supplies the value")
        self.assertEqual(dbg[0]["detail"].get("reason"), "external_file")

    def test_external_outside_target_unknown(self):
        files = dict(GLOBAL)
        files["Web.config"] = cfg('<system.web><compilation configSource="..\\shared\\compilation.config" />'
                                  '<customErrors configSource="C:\\conf\\errors.config" /></system.web>')
        doc = run(files)
        ext = of(doc, "config_external")
        self.assertEqual({(f["name"], f["detail"]["resolved"]) for f in ext},
                         {("system.web/compilation@configSource", False), ("system.web/customErrors@configSource", False)})
        self.assertTrue(all("target" not in f["detail"] for f in ext), "a path outside the Target is not recorded")
        for name in ("system.web/compilation@debug", "system.web/customErrors@mode"):
            d = [f for f in of(doc, "security_setting", name=name, config="base") if f["path"] == "Web.config"][0]["detail"]
            self.assertEqual((d["value"], d["config_status"]), ("unknown", "unknown_external"), name)

    def test_missing_target_inside_the_target_is_unresolved(self):
        files = dict(GLOBAL)
        files["Web.config"] = cfg('<appSettings file="gone.config"><add key="A" value="1" /></appSettings>'
                                  '<system.web><compilation debug="true" /></system.web>')
        ext = of(run(files), "config_external")
        self.assertEqual([(f["name"], f["detail"]["resolved"]) for f in ext], [("appSettings@file", False)])


class HostTests(unittest.TestCase):
    CSPROJ = ('<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003"><PropertyGroup>'
              '<ProjectTypeGuids>{349c5851-65df-11da-9384-00065b846f21}</ProjectTypeGuids>'
              '<UseIISExpress>true</UseIISExpress><IISExpressAnonymousAuthentication>enabled</IISExpressAnonymousAuthentication>'
              '</PropertyGroup></Project>')

    def test_host_auth_unknown_by_default(self):
        files = dict(GLOBAL)
        files["Web.config"] = cfg("<system.web><authentication mode=\"Windows\" /></system.web>")
        h = of(run(files), "host_auth")
        self.assertEqual(len(h), 1)
        self.assertEqual({k: h[0]["detail"][k] for k in ("iis_anonymous", "source", "owin_auth", "iis_authorization_present")},
                         {"iis_anonymous": "unknown", "source": "none", "owin_auth": False, "iis_authorization_present": False})

    def test_iis_express_csproj_not_used(self):
        files = dict(GLOBAL)
        files["Web.config"] = cfg("<system.web><authentication mode=\"Windows\" /></system.web>")
        files["App.csproj"] = self.CSPROJ
        d = of(run(files), "host_auth")[0]["detail"]
        self.assertEqual((d["iis_anonymous"], d["source"]), ("unknown", "csproj_dev_only"),
                         "dev-only values are disclosed, never used as the host's setting")

    def test_iis_config_literal_is_used(self):
        files = dict(GLOBAL)
        files["Web.config"] = cfg('<system.webServer><security><authentication>'
                                  '<anonymousAuthentication enabled="false" /></authentication>'
                                  '<authorization><add accessType="Allow" users="*" /></authorization></security></system.webServer>'
                                  '<system.web><authentication mode="Windows" /></system.web>')
        files["App.csproj"] = self.CSPROJ
        d = of(run(files), "host_auth")[0]["detail"]
        self.assertEqual((d["iis_anonymous"], d["source"], d["iis_authorization_present"]), ("disabled", "config", True))

    def test_owin_auth_detected(self):
        files = dict(GLOBAL)
        files["Web.config"] = cfg("<system.web><authentication mode=\"None\" /></system.web>")
        files["Startup.cs"] = ("using Owin;\npublic class Startup {\n  public void Configuration(IAppBuilder app) {\n"
                               "    app.UseCookieAuthentication(new CookieAuthenticationOptions());\n  }\n}\n")
        d = of(run(files), "host_auth")[0]["detail"]
        self.assertIs(d["owin_auth"], True)
        files.pop("Startup.cs")
        files["packages.config"] = '<packages><package id="Microsoft.Owin.Security.Cookies" version="4.0.0" /></packages>'
        self.assertIs(of(run(files), "host_auth")[0]["detail"]["owin_auth"], True)
        files.pop("packages.config")
        self.assertIs(of(run(files), "host_auth")[0]["detail"]["owin_auth"], False)


class RuleTests(unittest.TestCase):
    PATH = "Web.config"

    def rules(self, text, path=None):
        return facts(path or self.PATH, text, "access_rule")

    def test_location_rules(self):
        text = cfg("""<system.web><authorization><allow roles="A,B" /><deny users="*" /></authorization></system.web>
<location path="Billing"><system.web><authorization><allow roles="C" /><deny users="?" /></authorization></system.web></location>""")
        got = [(f.detail_dict()["scope_path"], f.detail_dict()["effect"], f.detail_dict().get("roles")) for f in self.rules(text)]
        self.assertEqual(got, [("", "allow", ["A", "B"]), ("", "deny", None), ("Billing", "allow", ["C"]),
                               ("Billing", "deny", None)])
        d = self.rules(text)[2].detail_dict()
        self.assertEqual((d["config"], d["config_status"], d["file"], d["location"]), ("base", "base", "Web.config", "Billing"))
        folder = self.rules(text, "Admin/Web.config")[0].detail_dict()
        self.assertEqual(folder["scope_path"], "Admin", "the file's folder joined with location@path")

    def test_rule_order_recorded(self):
        text = cfg("""<system.web><authorization><allow roles="A" /><deny users="*" /></authorization></system.web>
<location path="X"><system.web><authorization><deny users="?" /><allow users="*" /></authorization></system.web></location>""")
        self.assertEqual([f.detail_dict()["order"] for f in self.rules(text)], [1, 2, 3, 4], "document order in the file")
        self.assertEqual([f.line for f in self.rules(text)], [3, 3, 4, 4], "each rule cites its own element")

    def test_verbs_recorded(self):
        text = cfg('<system.web><authorization><deny verbs="post, Put" users="?" /><allow users="*" /></authorization></system.web>')
        a, b = [f.detail_dict() for f in self.rules(text)]
        self.assertEqual(a["verbs"], ["POST", "PUT"])
        self.assertNotIn("verbs", b, "no verbs list means all verbs")

    def test_clear_and_remove_recorded(self):
        text = cfg('<system.web><authorization><clear /><remove users="*" /><allow roles="R" /></authorization></system.web>')
        got = [(f.detail_dict()["effect"], f.detail_dict().get("all")) for f in self.rules(text)]
        self.assertEqual(got, [("clear", None), ("remove", True), ("allow", None)])

    def test_users_flags_set(self):
        text = cfg('<system.web><authorization><allow users="?,*" /><deny users="?" /><allow users="*" />'
                   '<allow users="DOM\\a, dom\\A, DOM\\b" /></authorization></system.web>')
        d = [f.detail_dict() for f in self.rules(text)]
        self.assertEqual((d[0].get("anon"), d[0].get("all")), (True, True), "users=\"?,*\" is legal: both flags")
        self.assertEqual((d[1].get("anon"), d[1].get("all")), (True, None))
        self.assertEqual((d[2].get("anon"), d[2].get("all")), (None, True))
        self.assertEqual(d[3]["users_named"], 2, "counted, deduplicated case-insensitively")

    def test_named_users_counted_not_recorded(self):
        text = cfg('<system.web><authorization><allow users="CONTOSO\\pat,CONTOSO\\sam,contoso\\PAT" /></authorization></system.web>')
        fs = self.rules(text)
        self.assertEqual(fs[0].detail_dict()["users_named"], 2)
        blob = json.dumps([f.to_json() for f in fs]).lower()
        for leak in ("contoso", "\\\\pat", "\\\\sam", "sam"):
            self.assertNotIn(leak, blob)

    def test_roles_email_or_sid_counted_not_recorded(self):
        text = cfg('<system.web><authorization><allow roles="Admins,pat@contoso.test,S-1-5-21-111-222-333-1001,'
                   'CONTOSO\\Staff" /></authorization></system.web>')
        d = self.rules(text)[0].detail_dict()
        self.assertEqual(d["roles"], ["Admins", "CONTOSO\\Staff"], "DOMAIN\\X roles are kept")
        self.assertIs(d["domain_qualified"], True)
        self.assertEqual(d["users_named"], 2, "the email-like and SID-like roles are counted as users")
        blob = json.dumps(self.rules(text)[0].to_json())
        self.assertNotIn("pat@contoso", blob)
        self.assertNotIn("S-1-5-21", blob)

    def test_location_path_dot_and_absent(self):
        for attr in (' path="."', ' path=""', "", ' path="~/"', ' path="/"'):
            text = cfg(f'<location{attr}><system.web><authorization><allow roles="x" /></authorization></system.web></location>')
            self.assertEqual(self.rules(text)[0].detail_dict()["scope_path"], "", attr)

    def test_location_path_forms(self):
        for given, want in ((' path="~/Admin/"', "Admin"), (' path="/Admin"', "Admin"), (' path="Info\\Welcome"', "Info/Welcome"),
                            (' path="Unsubscribe.aspx"', "Unsubscribe.aspx"), (' path="./a/./b"', "a/b")):
            text = cfg(f'<location{given}><system.web><authorization><allow roles="x" /></authorization></system.web></location>')
            self.assertEqual(self.rules(text)[0].detail_dict()["scope_path"], want, given)

    def test_location_case_is_kept_and_compared_case_insensitively(self):
        self.assertEqual(S.norm_scope("", "ADMINTOOLS"), "ADMINTOOLS")
        doc = run({**GLOBAL, "Web.config": cfg('<system.web><authentication mode="Windows" /></system.web>'
                                               '<location path="ADMINTOOLS"><system.web><authorization><allow roles="x" /></authorization></system.web></location>'),
                   "admintools/readme.txt": "x"})
        self.assertEqual(summary.unmatched_rules(doc["facts"]), [], "a folder matches whatever its case")

    def test_location_segment_boundary(self):
        doc = run({**GLOBAL, "Web.config": cfg('<system.web><authentication mode="Windows" /></system.web>'
                                               '<location path="Admin"><system.web><authorization><allow roles="x" /></authorization></system.web></location>'),
                   "AdminTools/readme.txt": "x"})
        self.assertEqual([r["scope_path"] for r in summary.unmatched_rules(doc["facts"])], ["Admin"],
                         "Admin does not match the folder AdminTools")

    def test_allow_override_false_marks_unknown(self):
        files = {**GLOBAL, "Web.config": cfg('<system.web><authentication mode="Windows" /></system.web>'
                                              '<location path="Locked" allowOverride="false"><system.web><authorization>'
                                              '<deny users="*" /></authorization></system.web></location>'
                                              '<location path="Locked/Sub"><system.web><authorization><allow users="*" />'
                                              '</authorization></system.web></location>'
                                              '<location path="Free" allowOverride="false"><system.web><authorization>'
                                              '<deny users="?" /></authorization></system.web></location>'),
                 "Locked/Web.config": cfg('<system.web><authorization><allow roles="r" /></authorization></system.web>')}
        doc = run(files)
        by_scope = {}
        for f in of(doc, "access_rule", config="base"):
            by_scope.setdefault(f["detail"]["scope_path"], []).append(f["detail"])
        self.assertEqual(sorted(d["reason_codes"][0] for d in by_scope["Locked"]),
                         ["locked_with_nested_rules", "under_locked_scope"],
                         "the locking rule, and the nested Locked/Web.config rule it keeps from merging")
        self.assertEqual(by_scope["Locked/Sub"][0]["reason_codes"], ["under_locked_scope"])
        self.assertNotIn("reason_codes", by_scope["Free"][0], "a lock with nothing nested below stays evaluable")
        self.assertIs(by_scope["Free"][0]["allow_override"], False)

    def test_inherit_in_child_applications_disclosed(self):
        text = cfg('<location path="P" inheritInChildApplications="false"><system.web><authorization>'
                   '<deny users="?" /></authorization></system.web></location>')
        self.assertIs(self.rules(text)[0].detail_dict()["inherit_in_child_apps"], False)

    def test_location_system_webserver_not_read_as_authorization(self):
        text = cfg('<location path="Legacy"><system.webServer><security><authorization>'
                   '<add accessType="Allow" users="*" /></authorization></security></system.webServer></location>')
        self.assertEqual(self.rules(text), [])
        host = facts("Web.config", text, "host_auth")
        self.assertEqual([f.detail_dict() for f in host], [{"iis_authorization_present": True}], "recorded as IIS rules")

    def test_commented_rule_is_not_a_fact(self):
        text = cfg('<system.web><authorization><!-- <deny users="*" /> --><allow roles="x" /></authorization></system.web>')
        self.assertEqual([f.detail_dict()["effect"] for f in self.rules(text)], ["allow"])

    def test_root_rule_transformed(self):
        files = {**GLOBAL,
                 "Web.config": cfg('<system.web><authentication mode="Windows" /><authorization><allow roles="A" /><deny users="*" /></authorization></system.web>'),
                 "Web.Release.config": '<configuration xmlns:xdt="http://schemas.microsoft.com/XML-Document-Transform">'
                                       '<system.web><authorization xdt:Transform="Replace"><deny users="?" /><allow users="*" /></authorization></system.web></configuration>'}
        doc = run(files)
        rel = sorted(of(doc, "access_rule", config="Release"), key=lambda f: f["detail"]["order"])
        self.assertEqual([(f["detail"]["effect"], f["detail"]["config_status"]) for f in rel],
                         [("deny", "transformed"), ("allow", "transformed")])
        self.assertTrue(all(f["path"] == "Web.config" for f in rel), "an effective rule belongs to the base file")
        self.assertEqual({f["detail"]["file"] for f in rel}, {"Web.Release.config"})
        base = of(doc, "access_rule", config="base")
        self.assertEqual([f["detail"]["effect"] for f in base], ["allow", "deny"], "the base is never overwritten")

    def test_unmatched_rule_listed(self):
        files = {**GLOBAL, "Web.config": cfg('<system.web><authentication mode="Windows" /></system.web>'
                                              '<location path="Gone"><system.web><authorization><allow users="*" /></authorization></system.web></location>'
                                              '<location path="Here"><system.web><authorization><allow users="*" /></authorization></system.web></location>'
                                              '<location path="Routed/Deep"><system.web><authorization><deny users="?" /></authorization></system.web></location>'),
                 "Here/page.aspx": "<%@ Page Language=\"C#\" %>",
                 "Controllers/RoutedController.cs": "using System.Web.Mvc;\nnamespace Contoso.A.Controllers {\n public class RoutedController : Controller {\n"
                                                   "  public ActionResult Deep() { return View(); }\n }\n}\n"}
        got = summary.unmatched_rules(run(files)["facts"])
        self.assertEqual([(r["scope_path"], r["effect"]) for r in got], [("Gone", "allow")])
        self.assertEqual(sorted(r["path"] for r in got), ["Web.config"])
        text = summary.render_summary(run(files))
        self.assertIn("## Access rules matching nothing", text)
        self.assertIn("| allow | `Gone` | `Web.config:", text)
        self.assertNotIn("`Here`", text.split("## Access rules matching nothing")[1])

    def test_malformed_config_is_one_unparsed_and_no_rules(self):
        files = {**GLOBAL, "Web.config": "<configuration><system.web><authorization><allow roles=\"x\"\n</authorization>"}
        doc = run(files)
        self.assertEqual([(f["path"], f["detail"]["reason"]) for f in of(doc, "config_unparsed")], [("Web.config", "malformed")])
        self.assertEqual(of(doc, "access_rule"), [])
        self.assertEqual(of(doc, "security_setting"), [])

    def test_doctype_config_is_unparsed_dtd(self):
        files = {**GLOBAL, "Web.config": '<!DOCTYPE c [<!ENTITY a "b">]><configuration/>'}
        self.assertEqual([f["detail"]["reason"] for f in of(run(files), "config_unparsed")], ["dtd"])


if __name__ == "__main__":
    unittest.main()
