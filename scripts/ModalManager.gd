extends RefCounted
## ModalManager — confirmation/report dialogs with a build/present split.
## Original code. build_* returns an unparented dialog (headless-testable);
## present() parents it, applies the live theme, wires lifecycle (any close
## frees the dialog), and pops it. Callers connect `confirmed` to their own
## execute path BEFORE presenting; both connections fire on confirm.
## NOTE: no class_name; load via preload const MODAL.

static func build_confirm(title: String, body: String, ok_text: String = "Confirm") -> ConfirmationDialog:
	var d := ConfirmationDialog.new()
	d.title = title
	d.dialog_text = body
	d.ok_button_text = ok_text
	d.cancel_button_text = "Turn Back"
	return d

static func build_report(title: String, lines: PackedStringArray, ok_text: String = "Onward") -> AcceptDialog:
	var d := AcceptDialog.new()
	d.title = title
	d.dialog_text = "\n".join(lines)
	d.ok_button_text = ok_text
	return d

static func present(host: Node, dlg: Window) -> void:
	## Lifecycle first (close always frees), theme from the live tree, then pop.
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	if host is Control:
		var th: Theme = (host as Control).get_theme()
		if th != null:
			dlg.theme = th
	host.add_child(dlg)
	dlg.popup_centered()
