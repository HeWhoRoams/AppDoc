package smells;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;

@Controller
class FlashController {

	private static final String VIEW_FORM = "owners/form";

	@PostMapping("/bad")
	public String bad(Owner owner, BindingResult result, RedirectAttributes redirectAttributes) {
		if (result.hasErrors()) {
			redirectAttributes.addFlashAttribute("error", "There was an error.");
			return VIEW_FORM;
		}
		return "redirect:/ok";
	}

	@PostMapping("/bad-literal")
	public String badLiteral(RedirectAttributes redirectAttributes) {
		redirectAttributes.addFlashAttribute("message", "Saved");
		return "owners/list";
	}

	@PostMapping("/good")
	public String good(RedirectAttributes redirectAttributes) {
		redirectAttributes.addFlashAttribute("message", "Saved");
		return "redirect:/owners/" + 1;
	}

	@PostMapping("/commented")
	public String commented(RedirectAttributes redirectAttributes) {
		// redirectAttributes.addFlashAttribute("message", "Saved");
		return "owners/list";
	}
}
