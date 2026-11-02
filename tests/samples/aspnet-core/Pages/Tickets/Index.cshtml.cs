using Microsoft.AspNetCore.Mvc.RazorPages;

namespace HelpDesk.TicketApi.Pages.Tickets
{
    public class IndexModel : PageModel
    {
        public void OnGet()
        {
        }

        public async Task<IActionResult> OnPostAsync()
        {
            return Page();
        }
    }
}
