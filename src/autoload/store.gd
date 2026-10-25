extends Node
## The museum's archive: every prompt and collection, kept in one JSON file in
## the user folder. Writes go to a temp file first and are swapped in, and the
## previous good copy is kept as a backup, so a crash mid-save loses nothing.

signal changed

const FILE := "user://museum.json"
const BACKUP := "user://museum.bak.json"
const FORMAT := 1

## The models a prompt can be tagged for, in picker order.
const MODELS := ["Any", "Claude", "ChatGPT", "Gemini", "Midjourney", "Stable Diffusion", "DALL·E", "Suno", "Other"]

## Collection colours (the accent each wing of the museum is painted in).
const PALETTE := ["7c5cff", "3dd6f5", "ff6b9a", "ffb547", "4ade80", "f97362", "a78bfa", "22d3ee", "f472b6", "facc15"]

## Glyphs a collection can wear (see Icon.gd for how each one is drawn).
const GLYPHS := ["spark", "code", "pen", "image", "chat", "brain", "music", "briefcase", "book", "bolt", "heart", "globe"]

## Views that open like a wing but gather prompts from the whole museum.
const ALL := "@all"
const FAVS := "@fav"
const UNFILED := "@none"

var collections: Array = []
var prompts: Array = []
var settings := {"name": "", "sort": "recent"}

var _dirty := false
var _save_timer: Timer


func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.6
	_save_timer.timeout.connect(save_now)
	add_child(_save_timer)
	load_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty:
			save_now()


# ------------------------------------------------------------------ load & save

func load_data() -> void:
	var data = _read(FILE)
	if data == null:
		data = _read(BACKUP)
	if data == null:
		seed_samples()
		save_now()
		return
	from_dict(data)


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.has("prompts"):
		return parsed
	return null


func to_dict() -> Dictionary:
	return {"format": FORMAT, "collections": collections, "prompts": prompts, "settings": settings}


func from_dict(d: Dictionary) -> void:
	collections = []
	for c in d.get("collections", []):
		if c is Dictionary:
			collections.append(_clean_collection(c))
	prompts = []
	for p in d.get("prompts", []):
		if p is Dictionary:
			prompts.append(_clean_prompt(p))
	var s = d.get("settings", {})
	if s is Dictionary:
		settings.merge(s, true)


func save_soon() -> void:
	_dirty = true
	_save_timer.start()
	changed.emit()


func save_now() -> void:
	_dirty = false
	var text := JSON.stringify(to_dict(), "\t")
	var tmp := FILE + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Prompt Museum: couldn't save (%s)" % FileAccess.get_open_error())
		return
	f.store_string(text)
	f.close()
	var dir := DirAccess.open("user://")
	if dir.file_exists("museum.json"):
		if dir.file_exists("museum.bak.json"):
			dir.remove("museum.bak.json")
		dir.rename("museum.json", "museum.bak.json")
	dir.rename("museum.json.tmp", "museum.json")


# ------------------------------------------------------------------ records

static func new_id() -> String:
	return "%x%04x" % [int(Time.get_unix_time_from_system() * 1000.0), randi() % 0xffff]


static func now() -> int:
	return int(Time.get_unix_time_from_system())


func _clean_collection(c: Dictionary) -> Dictionary:
	return {
		"id": str(c.get("id", new_id())),
		"name": str(c.get("name", "Untitled wing")),
		"color": str(c.get("color", PALETTE[0])),
		"glyph": str(c.get("glyph", "spark")),
		"created": int(c.get("created", now())),
	}


func _clean_prompt(p: Dictionary) -> Dictionary:
	var tags: Array = []
	for t in p.get("tags", []):
		var s := str(t).strip_edges()
		if s != "" and not tags.has(s):
			tags.append(s)
	return {
		"id": str(p.get("id", new_id())),
		"title": str(p.get("title", "")),
		"body": str(p.get("body", "")),
		"collection": str(p.get("collection", "")),
		"tags": tags,
		"model": str(p.get("model", "Any")),
		"notes": str(p.get("notes", "")),
		"favorite": bool(p.get("favorite", false)),
		"uses": int(p.get("uses", 0)),
		"created": int(p.get("created", now())),
		"updated": int(p.get("updated", now())),
		"last_used": int(p.get("last_used", 0)),
	}


func get_prompt(id: String) -> Dictionary:
	for p in prompts:
		if p.id == id:
			return p
	return {}


func get_collection(id: String) -> Dictionary:
	for c in collections:
		if c.id == id:
			return c
	return {}


## Adds or replaces a prompt (matched by id) and returns the stored copy.
func put_prompt(p: Dictionary) -> Dictionary:
	var clean := _clean_prompt(p)
	clean.updated = now()
	for i in prompts.size():
		if prompts[i].id == clean.id:
			clean.created = prompts[i].created
			prompts[i] = clean
			save_soon()
			return clean
	prompts.push_front(clean)
	save_soon()
	return clean


func delete_prompt(id: String) -> Dictionary:
	for i in prompts.size():
		if prompts[i].id == id:
			var gone: Dictionary = prompts[i]
			prompts.remove_at(i)
			save_soon()
			return gone
	return {}


## Puts a deleted prompt back exactly as it was (the toast's Undo).
func restore_prompt(p: Dictionary) -> void:
	if p.is_empty() or not get_prompt(p.id).is_empty():
		return
	prompts.push_front(p)
	save_soon()


func put_collection(c: Dictionary) -> Dictionary:
	var clean := _clean_collection(c)
	for i in collections.size():
		if collections[i].id == clean.id:
			clean.created = collections[i].created
			collections[i] = clean
			save_soon()
			return clean
	collections.append(clean)
	save_soon()
	return clean


## Removes a collection; its prompts stay in the museum, unfiled.
func delete_collection(id: String) -> void:
	for i in collections.size():
		if collections[i].id == id:
			collections.remove_at(i)
			break
	for p in prompts:
		if p.collection == id:
			p.collection = ""
	save_soon()


func toggle_favorite(id: String) -> bool:
	var p := get_prompt(id)
	if p.is_empty():
		return false
	p.favorite = not p.favorite
	save_soon()
	return p.favorite


func mark_used(id: String) -> void:
	var p := get_prompt(id)
	if p.is_empty():
		return
	p.uses += 1
	p.last_used = now()
	save_soon()


func duplicate_prompt(id: String) -> Dictionary:
	var p := get_prompt(id)
	if p.is_empty():
		return {}
	var copy := p.duplicate(true)
	copy.id = new_id()
	copy.title = "%s (copy)" % p.title
	copy.uses = 0
	copy.last_used = 0
	copy.favorite = false
	copy.created = now()
	return put_prompt(copy)


# ------------------------------------------------------------------ queries

func in_collection(id: String) -> Array:
	return prompts.filter(func(p): return p.collection == id)


func count_in(id: String) -> int:
	var n := 0
	for p in prompts:
		if p.collection == id:
			n += 1
	return n


func favorites() -> Array:
	return prompts.filter(func(p): return p.favorite)


func recent(limit := 6) -> Array:
	var list := prompts.duplicate()
	list.sort_custom(func(a, b): return maxi(a.last_used, a.updated) > maxi(b.last_used, b.updated))
	return list.slice(0, limit)


func total_uses() -> int:
	var n := 0
	for p in prompts:
		n += p.uses
	return n


## Every tag in use, most used first.
func all_tags() -> Array:
	var counts := {}
	for p in prompts:
		for t in p.tags:
			counts[t] = counts.get(t, 0) + 1
	var tags := counts.keys()
	tags.sort_custom(func(a, b): return counts[a] > counts[b] if counts[a] != counts[b] else a.naturalnocasecmp_to(b) < 0)
	return tags


static func sorted(list: Array, mode: String) -> Array:
	var out := list.duplicate()
	match mode:
		"az":
			out.sort_custom(func(a, b): return a.title.naturalnocasecmp_to(b.title) < 0)
		"used":
			out.sort_custom(func(a, b): return a.uses > b.uses if a.uses != b.uses else a.updated > b.updated)
		_:
			out.sort_custom(func(a, b): return a.updated > b.updated)
	return out


## Scores how well a prompt matches a search: every word has to appear
## somewhere, and hits in the title count most, then tags, then the text.
static func match_score(p: Dictionary, query: String) -> int:
	var words := query.to_lower().split(" ", false)
	if words.is_empty():
		return 1
	var title: String = p.title.to_lower()
	var body: String = p.body.to_lower()
	var notes: String = p.notes.to_lower()
	var tags := " ".join(PackedStringArray(p.tags)).to_lower()
	var model: String = p.model.to_lower()
	var score := 0
	for raw in words:
		var w := raw.trim_prefix("#")
		if w == "":
			continue
		var s := 0
		if title.begins_with(w):
			s += 12
		elif title.contains(w):
			s += 8
		if tags.contains(w):
			s += 5
		if model.contains(w):
			s += 3
		if body.contains(w):
			s += 2
		if notes.contains(w):
			s += 1
		if s == 0:
			return 0
		score += s
	return score


func search(query: String) -> Array:
	var hits := []
	for p in prompts:
		var s := match_score(p, query)
		if s > 0:
			hits.append([s, p])
	hits.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1].updated > b[1].updated)
	return hits.map(func(h): return h[1])


# ------------------------------------------------------------------ variables

## The {{placeholders}} in a prompt, in the order they first appear.
static func variables(body: String) -> PackedStringArray:
	var out := PackedStringArray()
	var re := RegEx.create_from_string("\\{\\{\\s*([^{}\\s][^{}]*?)\\s*\\}\\}")
	for m in re.search_all(body):
		var name := m.get_string(1)
		if not out.has(name):
			out.append(name)
	return out


## The prompt with each {{placeholder}} swapped for its value; ones left
## blank stay as they were so they're easy to spot after pasting.
static func fill(body: String, values: Dictionary) -> String:
	var re := RegEx.create_from_string("\\{\\{\\s*([^{}\\s][^{}]*?)\\s*\\}\\}")
	var out := ""
	var at := 0
	for m in re.search_all(body):
		out += body.substr(at, m.get_start() - at)
		var v := str(values.get(m.get_string(1), ""))
		out += v if v != "" else m.get_string()
		at = m.get_end()
	return out + body.substr(at)


# ------------------------------------------------------------------ backup

func export_text() -> String:
	return JSON.stringify({"app": "Prompt Museum", "format": FORMAT, "collections": collections, "prompts": prompts}, "  ")


## Merges a backup in: records with an id already here are updated, new ones
## are added. Returns how many prompts came in, or -1 if it wasn't a backup.
func import_text(text: String) -> int:
	var json := JSON.new()
	if not text.strip_edges().begins_with("{") or json.parse(text.strip_edges()) != OK:
		return -1
	var d = json.data
	if not (d is Dictionary) or not (d.get("prompts") is Array):
		return -1
	for c in d.get("collections", []):
		if c is Dictionary:
			put_collection(c)
	var n := 0
	for p in d.prompts:
		if p is Dictionary:
			var clean := _clean_prompt(p)
			var found := false
			for i in prompts.size():
				if prompts[i].id == clean.id:
					prompts[i] = clean
					found = true
			if not found:
				prompts.append(clean)
			n += 1
	save_soon()
	return n


# ------------------------------------------------------------------ samples

## A first visit opens on a small curated exhibition rather than an empty hall.
func seed_samples() -> void:
	collections = []
	prompts = []
	var wings := [
		["Writing", "ff6b9a", "pen"],
		["Code", "3dd6f5", "code"],
		["Image art", "ffb547", "image"],
		["Thinking", "7c5cff", "brain"],
	]
	var ids := []
	for w in wings:
		var c := _clean_collection({"id": new_id(), "name": w[0], "color": w[1], "glyph": w[2]})
		collections.append(c)
		ids.append(c.id)
	var samples := [
		[0, "Rewrite in my voice", "Rewrite the text below so it sounds like me: {{tone}}, direct, no filler words, short sentences. Keep every fact. Don't add a conclusion.\n\nText:\n{{text}}", ["editing", "voice"], "Claude", true],
		[0, "Cold email that gets replies", "Write a cold email to {{recipient}} at {{company}} about {{offer}}. Under 120 words, one clear ask, a subject line under 6 words, and no buzzwords.", ["email", "sales"], "Any", false],
		[1, "Senior code review", "Act as a senior {{language}} engineer. Review this code for bugs, edge cases, performance and readability. List problems by severity, then show the corrected code.\n\n```\n{{code}}\n```", ["review", "debugging"], "Claude", true],
		[1, "Explain this error", "I got this error in {{language}}:\n\n{{error}}\n\nExplain what it means in plain words, the three most likely causes, and how to check each one.", ["debugging"], "Any", false],
		[2, "Cinematic portrait", "Cinematic portrait of {{subject}}, {{lighting}} lighting, 85mm lens, shallow depth of field, film grain, rich color grading, ultra detailed --ar 4:5 --style raw", ["portrait", "photo"], "Midjourney", true],
		[2, "Isometric diorama", "Tiny isometric diorama of {{scene}}, soft clay materials, pastel palette, tilt-shift, studio lighting, octane render, centered on a plain background", ["3d", "cute"], "Midjourney", false],
		[3, "First principles", "Break {{problem}} down to first principles. List the assumptions people usually make, challenge each one, and rebuild a solution from what's left.", ["strategy"], "Any", false],
		[3, "Devil's advocate", "Here's my plan: {{plan}}\n\nArgue against it as hard as you can. Find the weakest assumption, the most likely way it fails, and what I'd regret not checking.", ["decisions"], "Claude", false],
	]
	var t := now()
	for i in samples.size():
		var s: Array = samples[i]
		prompts.append(_clean_prompt({
			"id": new_id() + str(i), "title": s[1], "body": s[2], "collection": ids[s[0]],
			"tags": s[3], "model": s[4], "favorite": s[5], "created": t - i * 3600, "updated": t - i * 3600,
		}))
