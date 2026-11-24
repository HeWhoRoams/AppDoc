"""appdoc/dotnetcfg.py: the hardened expat reader shared by Web*.config, transforms, app.config, csproj, pubxml."""
import unittest

from appdoc import dotnetcfg as D

CFG = b"""<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.web>
    <authentication mode="Forms" />
  </system.web>
</configuration>
"""


def names(node):
    out = [node.name]
    for c in node.children:
        out.extend(names(c))
    return out


class ReaderTests(unittest.TestCase):
    def test_basic_tree_and_start_tag_lines(self):
        doc = D.parse(CFG)
        self.assertIsNone(doc.unparsed)
        self.assertEqual(doc.root.name, "configuration")
        auth = doc.root.find("system.web", "authentication")
        self.assertEqual((auth.line, auth.attrs["mode"]), (4, "Forms"))
        self.assertEqual(doc.root.line, 2)

    def test_doctype_rejected(self):
        doc = D.parse(b'<?xml version="1.0"?>\n<!DOCTYPE configuration [ <!ELEMENT a ANY> ]>\n<configuration/>')
        self.assertIsNone(doc.root)
        self.assertEqual(doc.unparsed, "dtd")

    def test_doctype_rejected_in_utf16(self):
        doc = D.parse('<!DOCTYPE c [<!ENTITY a "b">]><c/>'.encode("utf-16"))
        self.assertEqual((doc.root, doc.unparsed), (None, "dtd"))

    def test_entity_bomb_not_expanded(self):
        lols = "".join(f'<!ENTITY l{i} "&l{i-1};&l{i-1};&l{i-1};&l{i-1};&l{i-1};&l{i-1};&l{i-1};&l{i-1};&l{i-1};&l{i-1};">'
                       for i in range(1, 9))
        bomb = ('<?xml version="1.0"?><!DOCTYPE lolz [<!ENTITY l0 "lol">' + lols + ']><lolz>&l8;</lolz>').encode()
        doc = D.parse(bomb)
        self.assertEqual((doc.root, doc.unparsed), (None, "dtd"))

    def test_oversize_skipped_with_reason(self):
        big = b"<configuration><!--" + b"x" * (D.SOFT_CAP + 10) + b"--></configuration>"
        self.assertGreater(len(big), D.SOFT_CAP)
        doc = D.parse(big)
        self.assertEqual((doc.root, doc.unparsed), (None, "oversize"))
        # a caller may raise the cap, never past the hard cap
        self.assertIsNotNone(D.parse(big, max_bytes=D.HARD_CAP).root)
        doc = D.parse(b" " * (D.HARD_CAP + 1), max_bytes=D.HARD_CAP * 10)
        self.assertEqual(doc.unparsed, "oversize")

    def test_depth_cap(self):
        deep = b"<a>" * (D.MAX_DEPTH + 5) + b"</a>" * (D.MAX_DEPTH + 5)
        self.assertEqual(D.parse(deep).unparsed, "oversize")
        ok = b"<a>" * (D.MAX_DEPTH - 1) + b"</a>" * (D.MAX_DEPTH - 1)
        self.assertIsNone(D.parse(ok).unparsed)

    def test_line_number_of_multiline_start_tag(self):
        doc = D.parse(b'<configuration>\n  <appSettings>\n    <add\n        key="a"\n        value="b"\n    />\n'
                      b'  </appSettings>\n</configuration>')
        add = doc.root.find("appSettings", "add")
        self.assertEqual(add.line, 3)  # the line of the start tag's "<", not of its last attribute

    def test_commented_rule_not_a_fact(self):
        doc = D.parse(b'<configuration><system.web><authorization>\n<!-- <deny users="?" /> -->\n'
                      b'<allow users="*"/><![CDATA[<deny users="x"/>]]>\n</authorization></system.web></configuration>')
        auth = doc.root.find("system.web", "authorization")
        self.assertEqual([c.name for c in auth.children], ["allow"])

    def test_line_numbers_survive_crlf_and_bom(self):
        text = '<?xml version="1.0" encoding="utf-8"?>\r\n<configuration>\r\n  <a>\r\n    <b/>\r\n  </a>\r\n</configuration>\r\n'
        for data in (text.encode("utf-8"), b"\xef\xbb\xbf" + text.encode("utf-8"),
                     text.replace("utf-8", "utf-16").encode("utf-16")):
            with self.subTest(prefix=data[:3]):
                doc = D.parse(data)
                self.assertIsNone(doc.unparsed)
                self.assertEqual(doc.root.find("a", "b").line, 4)

    def test_declared_encoding_honoured(self):
        data = '<?xml version="1.0" encoding="windows-1252"?><c><a v="caf\xe9"/></c>'.encode("cp1252")
        self.assertEqual(D.parse(data).root.find("a").attrs["v"], "caf\xe9")
        bad = D.parse(b'<?xml version="1.0" encoding="x-unknown-9"?><c/>')
        self.assertEqual((bad.root, bad.unparsed), (None, "encoding"))

    def test_namespaced_config_read(self):
        doc = D.parse(b'<configuration xmlns="http://schemas.microsoft.com/.NetConfiguration/v2.0">'
                      b'<system.web><compilation debug="true"/></system.web></configuration>')
        self.assertEqual(doc.root.name, "configuration")
        self.assertEqual(doc.root.find("system.web", "compilation").attrs["debug"], "true")

    def test_xdt_namespace_not_prefix(self):
        for uri in ("http://schemas.microsoft.com/XML-Document-Transform",
                    "https://schemas.microsoft.com/XML-Document-Transform"):
            for prefix in ("xdt", "t"):
                with self.subTest(uri=uri, prefix=prefix):
                    doc = D.parse(('<configuration xmlns:%s="%s"><system.web>'
                                   '<compilation %s:Transform="RemoveAttributes(debug)" %s:Locator="Match(name)" debug="x"/>'
                                   '</system.web></configuration>' % (prefix, uri, prefix, prefix)).encode())
                    c = doc.root.find("system.web", "compilation")
                    self.assertEqual(c.xdt, {"Transform": "RemoveAttributes(debug)", "Locator": "Match(name)"})
                    self.assertEqual(c.attrs, {"debug": "x"})
        # a literal xdt prefix bound to some other namespace is not XDT
        doc = D.parse(b'<configuration xmlns:xdt="urn:other"><a xdt:Transform="Replace"/></configuration>')
        self.assertEqual(doc.root.find("a").xdt, {})

    def test_filename_case_insensitive(self):
        for p in ("Web.config", "web.CONFIG", "a/b/WEB.Config", "App.Config"):
            self.assertTrue(D.is_config_name(p), p)
        self.assertEqual(D.transform_config_name("src/WEB.Release.CONFIG"), "Release")
        self.assertEqual(D.transform_config_name("Web.QA Test.config"), "QA Test")
        self.assertIsNone(D.transform_config_name("Web.config"))
        self.assertIsNone(D.transform_config_name("web.config.bak"))
        self.assertTrue(D.is_project_name("X.CSPROJ"))
        self.assertTrue(D.is_pubxml_name("p/Properties/PublishProfiles/Prod.PubXml"))
        self.assertFalse(D.is_pubxml_name("p/Properties/PublishProfiles/Prod.pubxml.user"))

    def test_malformed_gives_one_unparsed(self):
        for data in (b"<configuration><a></configuration>", b"<a><b/>", b"", b"not xml", b"<a/><b/>"):
            with self.subTest(data=data):
                doc = D.parse(data)
                self.assertIsNone(doc.root)  # no partial tree
                self.assertEqual(doc.unparsed, "malformed")

    def test_enumeration_per_attribute(self):
        self.assertEqual(D.enum_value("sessionState", "mode", "InProc"), "inproc")
        self.assertEqual(D.enum_value("sessionState", "mode", "Passport"), "other")
        self.assertEqual(D.enum_value("authentication", "mode", "Passport"), "passport")
        self.assertEqual(D.enum_value("authentication", "mode", " FORMS "), "forms")
        self.assertEqual(D.enum_value("httpRuntime", "requestValidationMode", "4.5"), "4.5")
        self.assertEqual(D.enum_value("httpRuntime", "requestValidationMode", "3.0"), "other")
        self.assertEqual(D.enum_value("customErrors", "mode", "RemoteOnly"), "remoteonly")
        self.assertEqual(D.enum_value("compilation", "debug", "TRUE"), "true")
        # an attribute with no enumeration never yields its value
        self.assertEqual(D.enum_value("compilation", "targetFramework", "4.8"), "other")
        self.assertEqual(D.enum_value("unknownElement", "mode", "off"), "other")

    def test_element_text_is_stripped_and_includes_cdata(self):
        doc = D.parse(b"<c><a>\n  Exe \n</a><b><![CDATA[ x<y ]]></b><!-- no --></c>")
        self.assertEqual((doc.root.find("a").text, doc.root.find("b").text), ("Exe", "x<y"))


if __name__ == "__main__":
    unittest.main()
