namespace Contoso.Portal.Infrastructure
{
    public static class Roles
    {
        public const string Admin = "PortalAdmins";
        public const string Finance = "FinanceStaff";
        public const string Auditor = "Auditors";
        public const string Support = "SupportDesk";
        public const string Registrar = "RegistrarOffice";
        public const string Intern = "Interns";
    }

    public static class Groups
    {
        public const string FinanceGroup = "CONTOSO\\FinanceGroup";
        public const string OpsGroup = "CONTOSO\\OpsGroup";
    }

    public static class Accounts
    {
        public const string ServiceAccount = "svc-portal";
        public const string ServicePassword = "not-a-real-credential-0001";
    }
}
