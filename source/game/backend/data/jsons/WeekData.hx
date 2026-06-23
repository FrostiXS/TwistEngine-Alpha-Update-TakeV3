package game.backend.data.jsons;

import flixel.util.FlxStringUtil;
import haxe.extern.EitherType;
import haxe.io.Path;
import game.states.playstate.PlayState;
import haxe.Json;
import game.backend.utils.PathUtil;

abstract WeekDataKey(Array<String>) from Array<String>
{
	public var file(get, never):String;

	@:noCompletion inline function get_file()
		return this[0];

	public var modPack(get, never):String;

	@:noCompletion inline function get_modPack()
		return this[1];

	public function new(file:String, ?modPack:String)
	{
		this = [file, modPack];
	}
}

class WeekData
{
	public static final weeksDatas = new Map<String, WeekData>();
	public static final weeksListOrder = new Array<WeekDataKey>();

	public var fileName:String;
	public var data:WeekStruct;

	public function new(data:WeekStruct, ?fileName:String)
	{
		this.data = data;
		if (fileName != null)
			this.fileName = fileName;
	}

	public static function getDefaultSongMetaData(?genId:Bool):SongMetaData
		return
		{
		};

	public static function defaultWeekStruct():WeekStruct
	{
		return {
			songs: [getDefaultSongMetaData()],
			difficulties: ["easy", "normal", "hard"],
			isTwist: true,
			storyMenu: {
				storyName: "Title",
				description: "Description",
				weekCharacters: ["dad", "gf", "bf"],
				weekBackground: "stage",
				hideStoryMode: false,
				firstTimeBlocked: false,
				hiddenUntilUnlocked: false
			},
			hideInFreeplay: false
		};
	}

	public static function reloadWeeksFiles(?getFromAllLibs:Bool)
	{
		weeksDatas.clear();
		weeksListOrder.clearArray();

		final currentMod = ModsFolder.currentModFolderPath;
		var deJson:Dynamic = null;

		for (file in AssetsPaths.getFolderContent("weeks", true))
		{
			trace(file);
			if (PathUtil.extension(file) != 'json')
				continue;

			if (weeksDatas.exists(file))
				continue;

			try
			{
				deJson = Json.parse(Assets.getText(file));
			}
			catch (e)
			{
				CoolUtil.alert(e.message, "Error to Parse json: " + file);
				deJson = null;
			}
			if (deJson == null)
				continue;

			weeksDatas.set(file, addWeek(deJson, file));
			weeksListOrder.push(new WeekDataKey(file, currentMod));
		}
		trace(weeksDatas);
		trace(weeksListOrder);
	}

	public static function convertDifficulties(source:haxe.extern.EitherType<String, Array<String>>):Array<String>
	{
		if (source == null)
			return null;
		var diffs:Array<String> = (Std.isOfType(source, String) ? (source : String).split(",") : (source : Array<String>).copy());
		var i:Int = diffs.length - 1;
		var diff:String;
		while (i > 0)
		{
			diff = diffs[i];
			if (diff != null)
			{
				diff = diff.trim().toLowerCase();
				if (diff.length == 0)
					diffs.remove(diffs[i]);
				else
					diffs[i] = diff;
			}
			--i;
		}
		return diffs;
	}

	static function addWeek(data:Dynamic, ?fileName:String):WeekData
	{
		if (data == null)
			return null;

		if (Reflect.hasField(data, 'isTwist') && Reflect.field(data, 'isTwist') == true)
		{
			function convertToClass(dyn:Dynamic):SongMetaData
			{
				var song:SongMetaData = {};
				for (i in Reflect.fields(dyn))
					Reflect.setField(song, i, Reflect.field(dyn, i));
				return song;
			}
			var songsArray:Array<Dynamic> = cast data.songs;
			data.songs = songsArray == null ? [] : [for (i in songsArray) convertToClass(i)];
			data.difficulties = convertDifficulties(data.difficulties);

			if (data.storyMenu != null && (data.storyMenu.description == null || data.storyMenu.description == ""))
			{
				data.storyMenu.description = data.storyMenu.storyName;
			}

			return new WeekData(data, fileName);
		}
		else
		{
			final psychData:WeekFilePsych = cast data;

			var weekTextureName:String = psychData.weekName;
			if (weekTextureName == null || weekTextureName == "")
				weekTextureName = psychData.storyName != null ? psychData.storyName.toLowerCase() : "default";

			var weekDescription:String = "";

			if (Reflect.hasField(psychData, 'description') && Reflect.field(psychData, 'description') != null)
			{
				weekDescription = Reflect.field(psychData, 'description');
			}
			else if (psychData.storyName != null)
			{
				weekDescription = psychData.storyName;
			}
			else
			{
				weekDescription = "Play this week!";
			}

			var characterColors:Array<String> = null;
			if (Reflect.hasField(psychData, 'characterColors') && Reflect.field(psychData, 'characterColors') != null)
			{
				characterColors = Reflect.field(psychData, 'characterColors');
			}

			var bgGradientColor:Array<String> = null;
			if (Reflect.hasField(psychData, 'bgGradientColor') && Reflect.field(psychData, 'bgGradientColor') != null)
			{
				bgGradientColor = Reflect.field(psychData, 'bgGradientColor');
			}

			var boyfriendColor:String = Reflect.hasField(psychData, 'boyfriendColor') ? Reflect.field(psychData, 'boyfriendColor') : null;
			var girlfriendColor:String = Reflect.hasField(psychData, 'girlfriendColor') ? Reflect.field(psychData, 'girlfriendColor') : null;
			var dadColor:String = Reflect.hasField(psychData, 'dadColor') ? Reflect.field(psychData, 'dadColor') : null;

			return new WeekData({
				songs: [
					for (i in psychData.songs)
						{
							songName: i[0],
							healthIcon: i[1],
							freeplayColor: i[2],
							invisibleInFreeplay: psychData.hideFreeplay == true
						}
				],
				isTwist: false,
				difficulties: convertDifficulties(psychData.difficulties),
				hideInFreeplay: psychData.hideFreeplay == true,
				storyMenu: {
					storyName: psychData.storyName,
					weekName: weekTextureName,
					description: weekDescription,
					weekCharacters: psychData.weekCharacters,
					weekBackground: psychData.weekBackground,
					weekBefore: psychData.weekBefore,
					hideStoryMode: psychData.hideStoryMode == true,
					firstTimeBlocked: psychData.startUnlocked == true,
					hiddenUntilUnlocked: psychData.hiddenUntilUnlocked == true,
					characterColors: characterColors,
					bgGradientColor: bgGradientColor,
					boyfriendColor: boyfriendColor,
					girlfriendColor: girlfriendColor,
					dadColor: dadColor
				}
			}, fileName);
		}
	}
}

typedef StoryMenuData =
{
	> ExtraFields,
	storyName:String,
	?description:String,
	?weekName:String,
	?textImg:String,
	weekCharacters:Array<String>,
	?weekBackground:String,
	?hideStoryMode:Bool,
	?firstTimeBlocked:Bool,
	?hiddenUntilUnlocked:Bool,
	?weekBefore:String,
	?bgColor:String,
	?bgGradientColor:Array<String>,
	?characterColors:Array<String>,
	?boyfriendColor:String,
	?girlfriendColor:String,
	?dadColor:String
}

typedef WeekStruct =
{
	> ExtraFields,
	songs:Array<SongMetaData>,
	?difficulties:Array<String>,
	?storyMenu:StoryMenuData,
	isTwist:Bool,
	?hideInFreeplay:Bool
}

typedef WeekFilePsych =
{
	var songs:Array<Dynamic>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var freeplayColor:Array<Int>;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;

	@:optional var description:String;
	@:optional var characterColors:Array<String>;
	@:optional var bgGradientColor:Array<String>;
	@:optional var boyfriendColor:String;
	@:optional var girlfriendColor:String;
	@:optional var dadColor:String;
}

@:publicFields
@:structInit
class SongMetaData
{
	var songName:String = 'test';
	var displaySongName:String = null;
	var healthIcon:String = null;
	var freeplayColor:DynamicColor = 0xFFABCACA;
	var invisibleInFreeplay:Bool = false;
	var extraFields:Dynamic = null;

	public function toString()
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("displaySongName", displaySongName),
			LabelValuePair.weak("extraFields", extraFields),
			LabelValuePair.weak("freeplayColor", freeplayColor),
			LabelValuePair.weak("healthIcon", healthIcon),
			LabelValuePair.weak("invisibleInFreeplay", invisibleInFreeplay),
			LabelValuePair.weak("songName", songName),
		]);
}

typedef ExtraFields =
{
	?extraFields:Dynamic
}