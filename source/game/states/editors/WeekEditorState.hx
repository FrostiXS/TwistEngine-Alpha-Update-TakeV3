package game.states.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.Json;
import game.objects.ui.FlxInputText;
import game.backend.system.states.MusicBeatState;
import game.backend.utils.FileUtil;
import game.states.LoadingState;

/**
 * Week Editor — create and edit Twist Engine week files (.json).
 *
 * This state used to be an empty stub. It now provides a working UI to:
 *   - edit story-menu metadata (name, description, characters, background, weekBefore)
 *   - manage the song list (add / remove / navigate / rename + health icon)
 *   - edit difficulties (comma separated) and visibility toggles
 *   - load existing week json files and save them back to disk
 *
 * The output matches the native Twist week format (`isTwist: true`) read by WeekData.
 */
class WeekEditorState extends MusicBeatUIState
{
	var week:Dynamic;
	var curSong:Int = 0;

	// story menu inputs
	var storyNameInput:FlxInputText;
	var descInput:FlxInputText;
	var bgInput:FlxInputText;
	var weekBeforeInput:FlxInputText;
	var charOppInput:FlxInputText;
	var charGfInput:FlxInputText;
	var charBfInput:FlxInputText;
	var diffInput:FlxInputText;

	// song inputs
	var songNameInput:FlxInputText;
	var songIconInput:FlxInputText;
	var songLabel:FlxText;

	// toggle buttons
	var hideStoryBtn:FlxButton;
	var hiddenUnlockBtn:FlxButton;
	var firstBlockedBtn:FlxButton;
	var hideFreeplayBtn:FlxButton;

	override function create():Void
	{
		super.create();
		FlxG.mouse.visible = true;
		week = makeDefaultWeek();

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF1B1B2B);
		bg.scrollFactor.set();
		add(bg);

		var title = new FlxText(12, 8, FlxG.width - 24, "WEEK EDITOR", 28);
		title.setFormat(null, 28, FlxColor.WHITE, LEFT);
		add(title);

		var hint = new FlxText(12, 44, FlxG.width - 24,
			"Click a field to edit it. ESC = exit, CTRL+S = save, CTRL+O = load.", 12);
		hint.color = 0xFF9090A8;
		add(hint);

		// ---------- top buttons ----------
		var bx = FlxG.width - 4;
		bx -= 90; add(new FlxButton(bx, 10, "Exit", exitEditor));
		bx -= 90; add(new FlxButton(bx, 10, "Save", saveWeek));
		bx -= 90; add(new FlxButton(bx, 10, "Load", loadWeek));
		bx -= 90; add(new FlxButton(bx, 10, "New", newWeek));

		// ---------- left column: story menu ----------
		var lx = 16.0;
		var ly = 80.0;
		storyNameInput  = makeField(lx, ly, "Story Name (display title)"); ly += 52;
		descInput       = makeField(lx, ly, "Description");                ly += 52;
		bgInput         = makeField(lx, ly, "Week Background (stage name)");ly += 52;
		weekBeforeInput = makeField(lx, ly, "Week Before (unlocks after)"); ly += 52;
		charOppInput    = makeField(lx, ly, "Character: Opponent");        ly += 52;
		charGfInput     = makeField(lx, ly, "Character: Girlfriend");      ly += 52;
		charBfInput     = makeField(lx, ly, "Character: Boyfriend");       ly += 52;
		diffInput       = makeField(lx, ly, "Difficulties (comma list)");  ly += 60;

		// ---------- toggles ----------
		hideStoryBtn    = new FlxButton(lx, ly, "", function() { toggle("storyMenu", "hideStoryMode"); });        ly += 28;
		hiddenUnlockBtn = new FlxButton(lx, ly, "", function() { toggle("storyMenu", "hiddenUntilUnlocked"); });  ly += 28;
		firstBlockedBtn = new FlxButton(lx, ly, "", function() { toggle("storyMenu", "firstTimeBlocked"); });     ly += 28;
		hideFreeplayBtn = new FlxButton(lx, ly, "", function() { toggle(null, "hideInFreeplay"); });
		add(hideStoryBtn); add(hiddenUnlockBtn); add(firstBlockedBtn); add(hideFreeplayBtn);

		// ---------- right column: songs ----------
		var rx = 360.0;
		var ry = 80.0;
		var songsTitle = new FlxText(rx, ry - 26, 320, "SONGS", 20);
		songsTitle.color = FlxColor.WHITE;
		add(songsTitle);

		songLabel = new FlxText(rx, ry, 320, "", 14);
		songLabel.color = 0xFFB0B0C0;
		add(songLabel);
		ry += 26;

		songNameInput = makeField(rx, ry, "Song Name"); ry += 52;
		songIconInput = makeField(rx, ry, "Health Icon"); ry += 56;

		var sbx = rx;
		add(new FlxButton(sbx, ry, "< Prev", function() { syncCurrentSong(); curSong = Std.int(Math.max(0, curSong - 1)); refreshSong(); }));      sbx += 90;
		add(new FlxButton(sbx, ry, "Next >", function() { syncCurrentSong(); curSong = Std.int(Math.min(songCount() - 1, curSong + 1)); refreshSong(); })); sbx += 90;
		ry += 30;
		sbx = rx;
		add(new FlxButton(sbx, ry, "Add", addSong));    sbx += 90;
		add(new FlxButton(sbx, ry, "Remove", removeSong)); sbx += 90;

		refreshFromWeek();
	}

	// ===================== helpers =====================

	function makeField(x:Float, y:Float, label:String, width:Float = 300):FlxInputText
	{
		var t = new FlxText(x, y, width, label, 13);
		t.color = 0xFFB0B0C0;
		add(t);
		var input = new FlxInputText(x, y + 18, width, "", 14);
		add(input);
		return input;
	}

	inline function songCount():Int
		return (week.songs != null) ? week.songs.length : 0;

	function makeDefaultWeek():Dynamic
	{
		return {
			songs: [ { songName: "tutorial", healthIcon: "face", freeplayColor: [146, 113, 253], invisibleInFreeplay: false } ],
			difficulties: ["easy", "normal", "hard"],
			isTwist: true,
			hideInFreeplay: false,
			storyMenu: {
				storyName: "Title",
				description: "Description",
				weekCharacters: ["dad", "gf", "bf"],
				weekBackground: "stage",
				weekBefore: "",
				hideStoryMode: false,
				firstTimeBlocked: false,
				hiddenUntilUnlocked: false
			}
		};
	}

	function normalize():Void
	{
		if (week == null) week = makeDefaultWeek();
		if (week.storyMenu == null)
			Reflect.setField(week, "storyMenu", makeDefaultWeek().storyMenu);
		var sm = week.storyMenu;
		if (sm.weekCharacters == null || sm.weekCharacters.length < 3)
			Reflect.setField(sm, "weekCharacters", ["dad", "gf", "bf"]);
		if (week.difficulties == null)
			Reflect.setField(week, "difficulties", ["easy", "normal", "hard"]);
		if (week.songs == null)
			Reflect.setField(week, "songs", []);
		// upgrade plain-string songs (psych-style) to objects
		var fixed:Array<Dynamic> = [];
		for (s in (week.songs : Array<Dynamic>))
		{
			if (Std.isOfType(s, String))
				fixed.push({ songName: Std.string(s), healthIcon: "face", freeplayColor: [146, 113, 253], invisibleInFreeplay: false });
			else
				fixed.push(s);
		}
		Reflect.setField(week, "songs", fixed);
		if (week.songs.length == 0)
			week.songs.push({ songName: "newSong", healthIcon: "face", freeplayColor: [146, 113, 253], invisibleInFreeplay: false });
		Reflect.setField(week, "isTwist", true);
		curSong = Std.int(Math.max(0, Math.min(curSong, week.songs.length - 1)));
	}

	function gs(obj:Dynamic, field:String, def:String):String
	{
		if (obj != null && Reflect.hasField(obj, field) && Reflect.field(obj, field) != null)
			return Std.string(Reflect.field(obj, field));
		return def;
	}

	function gb(obj:Dynamic, field:String):Bool
	{
		return obj != null && Reflect.field(obj, field) == true;
	}

	// ===================== sync =====================

	function refreshFromWeek():Void
	{
		normalize();
		var sm = week.storyMenu;
		storyNameInput.text  = gs(sm, "storyName", "Title");
		descInput.text       = gs(sm, "description", "Description");
		bgInput.text         = gs(sm, "weekBackground", "stage");
		weekBeforeInput.text = gs(sm, "weekBefore", "");
		charOppInput.text    = Std.string(sm.weekCharacters[0]);
		charGfInput.text     = Std.string(sm.weekCharacters[1]);
		charBfInput.text     = Std.string(sm.weekCharacters[2]);
		diffInput.text       = (week.difficulties : Array<String>).join(", ");
		refreshSong();
		refreshToggles();
	}

	function refreshSong():Void
	{
		normalize();
		var s = week.songs[curSong];
		songNameInput.text = gs(s, "songName", "");
		songIconInput.text = gs(s, "healthIcon", "face");
		songLabel.text = "Song " + (curSong + 1) + " / " + songCount();
	}

	function refreshToggles():Void
	{
		var sm = week.storyMenu;
		hideStoryBtn.text    = "Hide Story Mode: " + (gb(sm, "hideStoryMode") ? "ON" : "OFF");
		hiddenUnlockBtn.text = "Hidden Until Unlocked: " + (gb(sm, "hiddenUntilUnlocked") ? "ON" : "OFF");
		firstBlockedBtn.text = "First Time Blocked: " + (gb(sm, "firstTimeBlocked") ? "ON" : "OFF");
		hideFreeplayBtn.text = "Hide In Freeplay: " + (gb(week, "hideInFreeplay") ? "ON" : "OFF");
	}

	function syncCurrentSong():Void
	{
		normalize();
		var s = week.songs[curSong];
		Reflect.setField(s, "songName", songNameInput.text);
		Reflect.setField(s, "healthIcon", songIconInput.text);
	}

	function syncToWeek():Void
	{
		normalize();
		var sm = week.storyMenu;
		Reflect.setField(sm, "storyName", storyNameInput.text);
		Reflect.setField(sm, "description", descInput.text);
		Reflect.setField(sm, "weekBackground", bgInput.text);
		Reflect.setField(sm, "weekBefore", weekBeforeInput.text);
		Reflect.setField(sm, "weekCharacters", [charOppInput.text, charGfInput.text, charBfInput.text]);

		var diffs:Array<String> = [];
		for (d in diffInput.text.split(","))
		{
			var t = StringTools.trim(d);
			if (t.length > 0) diffs.push(t);
		}
		if (diffs.length == 0) diffs = ["easy", "normal", "hard"];
		Reflect.setField(week, "difficulties", diffs);

		syncCurrentSong();
	}

	function toggle(parent:Null<String>, field:String):Void
	{
		var obj:Dynamic = (parent == null) ? week : Reflect.field(week, parent);
		Reflect.setField(obj, field, !(Reflect.field(obj, field) == true));
		refreshToggles();
	}

	// ===================== song ops =====================

	function addSong():Void
	{
		syncCurrentSong();
		week.songs.push({ songName: "newSong", healthIcon: "face", freeplayColor: [146, 113, 253], invisibleInFreeplay: false });
		curSong = Std.int(week.songs.length - 1);
		refreshSong();
	}

	function removeSong():Void
	{
		if (songCount() <= 1) return;
		week.songs.splice(curSong, 1);
		curSong = Std.int(Math.max(0, curSong - 1));
		refreshSong();
	}

	// ===================== file ops =====================

	function newWeek():Void
	{
		week = makeDefaultWeek();
		curSong = 0;
		refreshFromWeek();
	}

	function loadWeek():Void
	{
		FileUtil.browseForMultipleFiles([FileUtil.FILE_FILTER_JSON], function(paths:Array<String>)
		{
			if (paths == null || paths.length == 0) return;
			try
			{
				var raw = FileUtil.readStringFromPath(paths[0]);
				week = Json.parse(raw);
				curSong = 0;
				refreshFromWeek();
			}
			catch (e:Dynamic)
			{
				FlxG.log.error("Week Editor: failed to load file -> " + e);
			}
		});
	}

	function saveWeek():Void
	{
		syncToWeek();
		var data = Json.stringify(week, "\t");
		var fileName = StringTools.replace(StringTools.trim(storyNameInput.text), " ", "-").toLowerCase();
		if (fileName.length == 0) fileName = "week";
		FileUtil.browseForSaveFile([FileUtil.FILE_FILTER_JSON], function(path:String)
		{
			#if sys
			try { sys.io.File.saveContent(path, data); }
			catch (e:Dynamic) { FlxG.log.error("Week Editor: failed to save -> " + e); }
			#end
		}, null, null);
	}

	function exitEditor():Void
	{
		FlxG.mouse.visible = false;
		LoadingState.loadAndSwitchState(new MasterEditorMenu(), false);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!anyInputSelected())
		{
			if (FlxG.keys.justPressed.ESCAPE)
				exitEditor();
			else if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S)
				saveWeek();
			else if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.O)
				loadWeek();
		}
	}

	function anyInputSelected():Bool
	{
		var fields = [storyNameInput, descInput, bgInput, weekBeforeInput,
			charOppInput, charGfInput, charBfInput, diffInput, songNameInput, songIconInput];
		for (f in fields)
			if (f != null && f.selected) return true;
		return false;
	}
}
