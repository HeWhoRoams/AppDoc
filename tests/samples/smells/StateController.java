package smells;

@Controller
class StateController {

	@GetMapping("/owners/{id}/delete")
	public String deleteOwner(@PathVariable("id") int id) {
		this.owners.deleteById(id);
		return "redirect:/owners";
	}

	@GetMapping("/owners/{id}")
	public String show(@PathVariable("id") int id, Model model) {
		model.addAttribute("owner", this.owners.findById(id));
		return "owners/show";
	}

	@PostMapping("/owners/{id}/delete")
	public String deleteOwnerPost(@PathVariable("id") int id) {
		this.owners.deleteById(id);
		return "redirect:/owners";
	}

	@GetMapping("/commented")
	public String commented() {
		// this.owners.save(owner);
		return "x";
	}

	@GetMapping("/abstract")
	String declared();
}
