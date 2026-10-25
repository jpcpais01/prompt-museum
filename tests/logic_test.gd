extends Node
## Headless checks of the logic that doesn't need a screen: blanks, search,
## backups, version compare and patch-notes diffing. Run in CI before export.

var _fails := 0
var _passes := 0


func check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
	else:
		_fails += 1
		printerr("  FAIL: ", what)


func _ready() -> void:
	var U = load("res://src/autoload/updater.gd")
	# blanks
	var body := "Write about {{topic}} for {{ audience }}. More {{topic}}, {{ }} and {{a{b}}."
	var vars := Store.variables(body)
	check(vars == PackedStringArray(["topic", "audience"]), "variables found in order, deduped, trimmed: %s" % vars)
	var filled := Store.fill(body, {"topic": "cats", "audience": ""})
	check(filled.begins_with("Write about cats for {{ audience }}. More cats"), "fill swaps values and keeps empty blanks: %s" % filled)
	check(Store.fill("no blanks", {}) == "no blanks", "fill leaves plain text alone")

	# search scoring
	var p := {"title": "Senior code review", "body": "Review this python code", "tags": ["debugging"], "model": "Claude", "notes": ""}
	check(Store.match_score(p, "review") > Store.match_score(p, "python"), "title hits outrank body hits")
	check(Store.match_score(p, "#debugging") > 0, "#tag search matches tags")
	check(Store.match_score(p, "review rust") == 0, "every word must match")
	check(Store.match_score(p, "") == 1, "an empty query matches everything")

	# records and backups, on a scratch copy of the archive
	var keep_c := Store.collections.duplicate(true)
	var keep_p := Store.prompts.duplicate(true)
	Store.seed_samples()
	check(Store.collections.size() == 4 and Store.prompts.size() == 8, "samples seed four wings and eight prompts")
	var wing: String = Store.collections[0].id
	var n0 := Store.count_in(wing)
	var made := Store.put_prompt({"title": "T", "body": "B {{x}}", "collection": wing, "tags": ["a", " a ", "b", ""]})
	check(made.tags == ["a", "b"], "tags are trimmed and deduped: %s" % str(made.tags))
	check(Store.count_in(wing) == n0 + 1, "new prompt lands in its wing")
	var dup := Store.duplicate_prompt(made.id)
	check(dup.id != made.id and dup.title == "T (copy)", "duplicate gets a new id and title")
	var text := Store.export_text()
	var gone := Store.delete_prompt(made.id)
	check(Store.get_prompt(made.id).is_empty(), "delete removes it")
	Store.restore_prompt(gone)
	check(not Store.get_prompt(made.id).is_empty(), "undo restores it")
	Store.delete_collection(wing)
	check(Store.get_collection(wing).is_empty(), "deleting a wing removes it")
	check(Store.collections.size() == 3, "deleting a wing leaves the others")
	check(Store.get_prompt(made.id).collection == "", "deleting a wing unfiles its prompts")
	Store.collections = []
	Store.prompts = []
	var n := Store.import_text(text)
	check(n == 10 and Store.prompts.size() == 10 and Store.collections.size() == 4, "a backup imports back whole (%d)" % n)
	check(Store.import_text(text) == 10 and Store.prompts.size() == 10, "importing twice doesn't duplicate")
	check(Store.import_text("hello") == -1, "non-backups are refused")
	Store.mark_used(made.id)
	check(Store.get_prompt(made.id).uses == 1 and Store.total_uses() >= 1, "copies are counted")
	var az := Store.sorted(Store.prompts, "az")
	check(az[0].title.naturalnocasecmp_to(az[-1].title) <= 0, "A–Z sort")
	check(Store.all_tags().size() > 0, "tags are listed")
	Store.collections = keep_c
	Store.prompts = keep_p

	# updates
	check(U.is_newer("v0.1.10", "0.1.9"), "0.1.10 is newer than 0.1.9")
	check(not U.is_newer("0.1.9", "0.1.9"), "same version isn't newer")
	check(U.is_newer("1.0", "0.9.99"), "major beats minor")
	check(U.pick_asset([{"name": "PromptMuseum.apk"}, {"name": "PromptMuseum.exe"}], ".exe").name == "PromptMuseum.exe", "Windows picks the .exe")
	check(U.pick_asset([{"name": "x.zip"}], ".apk").is_empty(), "no asset yet means none")
	var mine := "## Old\n- One\n"
	var theirs := "## New\n- Two [b]\n## Old\n- One\n"
	var notes: String = U.new_notes(mine, theirs)
	check(notes.contains("Two [lb]b]") and not notes.contains("One"), "what's new lists only new entries, escaped: %s" % notes)

	print("logic: %d passed, %d failed" % [_passes, _fails])
	get_tree().quit(1 if _fails > 0 else 0)
