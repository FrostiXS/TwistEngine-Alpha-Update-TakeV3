package game.states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import game.objects.improvedFlixel.FlxFixedText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.display.FlxRuntimeShader;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.effects.FlxFlicker;
import game.backend.data.jsons.WeekData;
import game.backend.system.song.Song;
import game.states.playstate.PlayState;
import game.objects.MenuCharacter;
import game.backend.utils.Highscore;
import game.backend.utils.Difficulty;
import flixel.util.FlxColor;
#if DISCORD_RPC
import game.backend.system.net.Discord;
#end

class StoryMenuState extends MusicBeatState
{
	var curSelected:Int = 0;
	var curDifficulty:Int = 0;
	var loadedWeeks:Array<WeekData> = [];
	var currentWeekDifficulties:Array<String> = [];

	var bgSprite:FlxSprite;
	var txtDescription:FlxFixedText;
	var txtTracklist:FlxFixedText;
	var scoreText:FlxFixedText;
	var intendedScore:Int = 0;
	var lerpScore:Int = 0;

	var grpWeeks:FlxTypedGroup<FlxSprite>;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;
	var difficultySprite:FlxSprite;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;
	var topBlackBar:FlxSprite;
	var bgGradientShader:FlxRuntimeShader;

	var yPositions:Array<Float> = [];

	var targetTextDesc:String = "";
	var displayedIndicesDesc:Array<Int> = [];
	var isScramblingDesc:Bool = false;
	var scrambleTimerDesc:Float = 0;

	var targetTextTrack:String = "";
	var displayedIndicesTrack:Array<Int> = [];
	var isScramblingTrack:Bool = false;
	var scrambleTimerTrack:Float = 0;
	var glitchChars:String = "█▓▒░@#$%&!?";

	var weekIsSelected:Bool = false;

	var persistentCache:Array<FlxSprite> = [];
	var preloadedCharacters:Map<String, MenuCharacter> = new Map();

	override function create()
	{
		#if DISCORD_RPC
		DiscordClient.changePresence("In the Story Mode", null);
		#end

		WeekData.reloadWeeksFiles(true);
		if (FlxG.sound.music == null || !FlxG.sound.music.active)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));

		for (key in WeekData.weeksListOrder)
		{
			var week:WeekData = WeekData.weeksDatas.get(key.file);
			if (week != null && week.data.storyMenu != null && week.data.storyMenu.hideStoryMode != true)
			{
				loadedWeeks.push(week);
			}
		}

		if (loadedWeeks.length == 0)
		{
			var errorBg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
			add(errorBg);
			var errorText = new FlxFixedText(0, 0, FlxG.width, "Weeks not found", 75);
			errorText.setFormat(Paths.font("Better VCR 6.1.ttf"), 32, FlxColor.WHITE, CENTER);
			errorText.screenCenter(Y);
			add(errorText);

			super.create();
			return;
		}

		// Безопасный преднатяг ресурсов с проверками на null
		for (week in loadedWeeks)
		{
			var wData = week.data;
			var bgName = (wData.storyMenu != null && wData.storyMenu.weekBackground != null) ? wData.storyMenu.weekBackground : 'stage';
			var dummyBg = new FlxSprite().loadGraphic(Paths.image('menubackgrounds/' + bgName));
			persistentCache.push(dummyBg);

			var diffs = (wData.difficulties != null && wData.difficulties.length > 0) ? wData.difficulties : ["normal"];
			for (diff in diffs)
			{
				var dummyDiff = new FlxSprite().loadGraphic(Paths.image('menudifficulties/' + diff.toLowerCase()));
				persistentCache.push(dummyDiff);
			}

			if (wData.storyMenu != null && wData.storyMenu.weekCharacters != null)
			{
				for (charName in wData.storyMenu.weekCharacters)
				{
					if (charName != null && charName != '' && !preloadedCharacters.exists(charName))
					{
						var dummyChar = new MenuCharacter(0, charName);
						dummyChar.visible = false;
						dummyChar.active = false;
						preloadedCharacters.set(charName, dummyChar);
					}
				}
			}
		}

		grpWeeks = new FlxTypedGroup<FlxSprite>();
		add(grpWeeks);

		var currentY:Float = 550;
		for (i in 0...loadedWeeks.length)
		{
			var weekThing:FlxSprite = new FlxSprite(0, currentY);

			var wData = loadedWeeks[i].data;
			var weekImg:String = 'default';

			if (wData.storyMenu != null)
			{
				if (Reflect.hasField(wData.storyMenu, 'weekName') && Reflect.field(wData.storyMenu, 'weekName') != null)
					weekImg = Reflect.field(wData.storyMenu, 'weekName');
				else if (wData.storyMenu.storyName != null)
					weekImg = wData.storyMenu.storyName.toLowerCase();
			}

			// Пытаемся загрузить график, если не получается - используем default
			var graphic = Paths.image('storymenu/' + weekImg);
			if (graphic == null || graphic.bitmap == null)
			{
				weekImg = 'default';
				graphic = Paths.image('storymenu/default');
			}

			weekThing.loadGraphic(graphic);
			weekThing.screenCenter(X);
			weekThing.ID = i;
			yPositions.push(currentY);
			currentY += weekThing.height + 30;
			grpWeeks.add(weekThing);
		}

		topBlackBar = new FlxSprite(0, 0).makeGraphic(Std.int(FlxG.width), 56, FlxColor.BLACK);
		add(topBlackBar);

		bgSprite = new FlxSprite(0, 56);
		bgSprite.makeGraphic(FlxG.width, FlxG.height);
		bgSprite.scale.set(1, 1);
		bgSprite.updateHitbox();
		add(bgSprite);

		// Безопасная загрузка шейдера
		var shaderPath:String = Paths.file('shaders/engine/bgColorGradient.frag');
		if (shaderPath != null && openfl.utils.Assets.exists(shaderPath))
		{
			var shaderCode:String = openfl.utils.Assets.getText(shaderPath);
			if (shaderCode != null && shaderCode.length > 0)
			{
				bgGradientShader = new FlxRuntimeShader(shaderCode);
				bgSprite.shader = bgGradientShader;
			}
		}

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();
		for (charSlot in 0...3)
		{
			var posX:Float = (FlxG.width * 0.25) * (charSlot + 1) - 150;
			var weekChar:MenuCharacter = new MenuCharacter(posX, 'bf');
			weekChar.y += 70;
			grpWeekCharacters.add(weekChar);
		}
		add(grpWeekCharacters);

		txtDescription = new FlxFixedText(FlxG.width - 900, 20, 850, "", 24);
		txtDescription.setFormat(Paths.font("Better VCR 6.1.ttf"), 24, 0xFFB5B5B5, RIGHT);
		txtDescription.wordWrap = false;
		add(txtDescription);

		scoreText = new FlxFixedText(20, 20, 0, "WEEK SCORE: 0", 24);
		scoreText.setFormat(Paths.font("Better VCR 6.1.ttf"), 24, 0xFFB5B5B5, LEFT);
		add(scoreText);

		txtTracklist = new FlxFixedText(20, FlxG.height - 215, 400, "", 32);
		txtTracklist.setFormat(Paths.font("Better VCR 6.1.ttf"), 24, 0xFFE55777, CENTER);
		add(txtTracklist);

		var uiAtlas = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		var uiY:Float = 460;

		leftArrow = new FlxSprite(FlxG.width - 350, uiY);
		leftArrow.frames = uiAtlas;
		leftArrow.animation.addByPrefix('idle', 'arrow left');
		leftArrow.animation.addByPrefix('press', 'arrow push left');
	leftArrow.animation.play('idle');
		leftArrow.scale.set(0.7, 0.7);
		leftArrow.updateHitbox();
		add(leftArrow);

		difficultySprite = new FlxSprite(0, 0);
		difficultySprite.scale.set(0.8, 0.8);
		difficultySprite.updateHitbox();
		add(difficultySprite);

		rightArrow = new FlxSprite(leftArrow.x + 250, uiY);
		rightArrow.frames = uiAtlas;
		rightArrow.animation.addByPrefix('idle', 'arrow right');
		rightArrow.animation.addByPrefix('press', 'arrow push right');
		rightArrow.animation.play('idle');
		rightArrow.scale.set(0.7, 0.7);
		rightArrow.updateHitbox();
		add(rightArrow);

		if (loadedWeeks.length > 0)
			changeSelection(0);

		FlxG.mouse.visible = true;

		super.create();
	}

	function scrambleText(desc:String, track:String)
	{
		// Отменяем старые scramble-процессы
		isScramblingDesc = false;
		isScramblingTrack = false;

		targetTextDesc = desc.toUpperCase();
		displayedIndicesDesc = [];
		for (i in 0...targetTextDesc.length)
		{
			if (targetTextDesc.charAt(i) == ' ' || targetTextDesc.charAt(i) == '\n')
				displayedIndicesDesc.push(i);
		}
		scrambleTimerDesc = 0;
		isScramblingDesc = true;

		targetTextTrack = track.toUpperCase();
		displayedIndicesTrack = [];
		for (i in 0...targetTextTrack.length)
		{
			if (targetTextTrack.charAt(i) == ' ' || targetTextTrack.charAt(i) == '\n')
				displayedIndicesTrack.push(i);
		}
		scrambleTimerTrack = 0;
		isScramblingTrack = true;
	}

	override function update(elapsed:Float)
	{
		if (loadedWeeks.length == 0)
		{
			if (controls.BACK)
				MusicBeatState.switchState(new MainMenuState());

			super.update(elapsed);
			return;
		}

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, Math.min(1, elapsed * 30)));
		if (Math.abs(intendedScore - lerpScore) < 10)
			lerpScore = intendedScore;
		scoreText.text = "WEEK SCORE: " + lerpScore;

		if (!weekIsSelected)
		{
			if (controls.UI_UP_P)
				changeSelection(-1);
			if (controls.UI_DOWN_P)
				changeSelection(1);
			if (controls.UI_LEFT_P)
				changeDifficulty(-1);
			if (controls.UI_RIGHT_P)
				changeDifficulty(1);

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeSelection(-FlxG.mouse.wheel);
			}

			if (FlxG.mouse.justPressed)
			{
				if (FlxG.mouse.overlaps(leftArrow))
					changeDifficulty(-1);
				else if (FlxG.mouse.overlaps(rightArrow))
					changeDifficulty(1);
				else
				{
					grpWeeks.forEach(function(spr:FlxSprite)
					{
						if (FlxG.mouse.overlaps(spr))
						{
							if (curSelected != spr.ID)
							{
								changeSelection(spr.ID - curSelected);
							}
							else if (loadedWeeks.length > 0)
							{
								selectWeek();
							}
						}
					});
				}
			}

			if (controls.ACCEPT && loadedWeeks.length > 0)
				selectWeek();
			if (controls.BACK)
				MusicBeatState.switchState(new MainMenuState());
		}

		var leftPress = controls.UI_LEFT || (FlxG.mouse.pressed && FlxG.mouse.overlaps(leftArrow));
		var rightPress = controls.UI_RIGHT || (FlxG.mouse.pressed && FlxG.mouse.overlaps(rightArrow));
		leftArrow.animation.play(leftPress ? 'press' : 'idle');
		rightArrow.animation.play(rightPress ? 'press' : 'idle');

		if (isScramblingDesc)
		{
			scrambleTimerDesc += elapsed * 80;
			while (scrambleTimerDesc >= 1 && isScramblingDesc)
			{
				scrambleTimerDesc -= 1;
				var remainingIndices:Array<Int> = [];
				for (i in 0...targetTextDesc.length)
				{
					if (displayedIndicesDesc.indexOf(i) == -1)
						remainingIndices.push(i);
				}
				if (remainingIndices.length > 0)
					displayedIndicesDesc.push(remainingIndices[FlxG.random.int(0, remainingIndices.length - 1)]);
				else
					isScramblingDesc = false;
			}
			var currentDisplay:String = "";
			for (i in 0...targetTextDesc.length)
			{
				if (displayedIndicesDesc.indexOf(i) != -1)
					currentDisplay += targetTextDesc.charAt(i);
				else
					currentDisplay += glitchChars.charAt(FlxG.random.int(0, glitchChars.length - 1));
			}
			txtDescription.text = currentDisplay;
		}

		if (isScramblingTrack)
		{
			scrambleTimerTrack += elapsed * 80;
			while (scrambleTimerTrack >= 1 && isScramblingTrack)
			{
				scrambleTimerTrack -= 1;
				var remainingIndices:Array<Int> = [];
				for (i in 0...targetTextTrack.length)
				{
					if (displayedIndicesTrack.indexOf(i) == -1)
						remainingIndices.push(i);
				}
				if (remainingIndices.length > 0)
					displayedIndicesTrack.push(remainingIndices[FlxG.random.int(0, remainingIndices.length - 1)]);
				else
					isScramblingTrack = false;
			}
			var currentDisplay:String = "";
			for (i in 0...targetTextTrack.length)
			{
				if (displayedIndicesTrack.indexOf(i) != -1)
					currentDisplay += targetTextTrack.charAt(i);
				else
					currentDisplay += glitchChars.charAt(FlxG.random.int(0, glitchChars.length - 1));
			}
			txtTracklist.text = "TRACKS:\n\n" + currentDisplay;
		}

		grpWeeks.forEach(function(spr:FlxSprite)
		{
			var dist:Float = Math.abs(spr.ID - curSelected);
			var targetY:Float = yPositions[spr.ID] - (yPositions[curSelected] - 475);
			spr.y = FlxMath.lerp(spr.y, targetY, 0.05);
			spr.screenCenter(X);
			spr.alpha = FlxMath.lerp(spr.alpha, Math.max(0.0, 1.0 - (dist * 0.5)), 0.15);
			var scale = Math.max(0.5, 1.0 - (dist * 0.15));
			spr.scale.set(FlxMath.lerp(spr.scale.x, scale, 0.15), FlxMath.lerp(spr.scale.y, scale, 0.15));
		});

		super.update(elapsed);
	}

	function changeSelection(change:Int = 0)
	{
		if (change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'));

		curSelected += change;
		if (curSelected >= loadedWeeks.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = loadedWeeks.length - 1;

		var currentWeek = loadedWeeks[curSelected].data;

		currentWeekDifficulties = (currentWeek.difficulties != null && currentWeek.difficulties.length > 0) ? currentWeek.difficulties : ["normal"];
		curDifficulty = 0;
		updateDifficultyDisplay();

		var trackString:String = "";
		for (song in currentWeek.songs)
			trackString += song.songName + "\n";

		var desc = (currentWeek.storyMenu != null && currentWeek.storyMenu.description != null) ? currentWeek.storyMenu.description : "";
		scrambleText(desc, trackString);

		var bgName:String = (currentWeek.storyMenu != null
			&& currentWeek.storyMenu.weekBackground != null) ? currentWeek.storyMenu.weekBackground : 'stage';
		bgSprite.loadGraphic(Paths.image('menubackgrounds/' + bgName));

		var topColor:FlxColor = 0xFFE4CC6A;
		var botColor:FlxColor = 0xFFDCAB4A;

		if (currentWeek.storyMenu != null
			&& currentWeek.storyMenu.bgGradientColor != null
			&& currentWeek.storyMenu.bgGradientColor.length >= 2)
		{
			topColor = FlxColor.fromString(currentWeek.storyMenu.bgGradientColor[0]);
			botColor = FlxColor.fromString(currentWeek.storyMenu.bgGradientColor[1]);
		}

		if (bgGradientShader != null)
		{
			bgGradientShader.setFloatArray('u_topColor', [topColor.redFloat, topColor.greenFloat, topColor.blueFloat]);
			bgGradientShader.setFloatArray('u_botColor', [botColor.redFloat, botColor.greenFloat, botColor.blueFloat]);
		}

		// Обновление персонажей с проверкой границ
		var weekCharacters = (currentWeek.storyMenu != null && currentWeek.storyMenu.weekCharacters != null)
			? currentWeek.storyMenu.weekCharacters : [];
		var characterColors = (currentWeek.storyMenu != null && currentWeek.storyMenu.characterColors != null)
			? currentWeek.storyMenu.characterColors : [];

		for (i in 0...grpWeekCharacters.members.length)
		{
			var charSprite = grpWeekCharacters.members[i];
			var charName = (i < weekCharacters.length) ? weekCharacters[i] : null;

			if (charName != null && charName != '')
			{
				charSprite.visible = true;
				charSprite.changeCharacter(charName);
				if (i < characterColors.length && characterColors[i] != null)
					charSprite.color = FlxColor.fromString(characterColors[i]);
				else
					charSprite.color = FlxColor.WHITE;
			}
			else
			{
				charSprite.visible = false;
			}
		}
	}

	function changeDifficulty(change:Int = 0)
	{
		if (change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'));
		curDifficulty += change;
		if (curDifficulty < 0)
			curDifficulty = currentWeekDifficulties.length - 1;
		if (curDifficulty >= currentWeekDifficulties.length)
			curDifficulty = 0;
		updateDifficultyDisplay();
	}

	function updateDifficultyDisplay()
	{
		var diffName:String = currentWeekDifficulties[curDifficulty].toLowerCase();

		difficultySprite.animation.destroyAnimations();

		if (diffName == "nightmare")
		{
			var atlasPath = Paths.getSparrowAtlas('menudifficulties/' + diffName);
			if (atlasPath != null)
			{
				difficultySprite.frames = atlasPath;
				difficultySprite.animation.addByPrefix('idle', 'idle', 60, true);
				difficultySprite.animation.play('idle');
			}
			else
			{
				// Fallback на статичное изображение
				var graphic = Paths.image('menudifficulties/' + diffName);
				if (graphic != null)
					difficultySprite.loadGraphic(graphic);
			}
		}
		else
		{
			var graphic = Paths.image('menudifficulties/' + diffName);
			if (graphic != null)
				difficultySprite.loadGraphic(graphic);
		}

		difficultySprite.updateHitbox();

		if (diffName == "normal" || diffName == "erect")
		{
			difficultySprite.scale.set(0.6, 0.6);
			difficultySprite.updateHitbox();
		}
		else if (diffName == "nightmare")
		{
			difficultySprite.scale.set(0.65, 0.65);
			difficultySprite.updateHitbox();
		}
		else
		{
			difficultySprite.scale.set(0.8, 0.8);
			difficultySprite.updateHitbox();
		}

		var arrowGap:Float = (rightArrow.x + rightArrow.width) - leftArrow.x;
		difficultySprite.x = leftArrow.x + (arrowGap / 2) - (difficultySprite.width / 2);

		if (diffName == "nightmare")
			difficultySprite.x -= 5;

		var targetY:Float = leftArrow.y + (leftArrow.height / 2) - (difficultySprite.height / 2);

		difficultySprite.y = targetY - 15;
		difficultySprite.alpha = 0;

		FlxTween.cancelTweensOf(difficultySprite);
		FlxTween.tween(difficultySprite, {y: targetY, alpha: 1}, 0.07);

		var weekData = Highscore.getWeekData(loadedWeeks[curSelected].fileName, Difficulty.getString(curDifficulty));
		intendedScore = (weekData != null) ? weekData.score : 0;
	}

	function selectWeek()
	{
		if (weekIsSelected)
			return;
		weekIsSelected = true;
		FlxG.mouse.visible = false;
		var week = loadedWeeks[curSelected];
		var playlist:Array<String> = [for (song in week.data.songs) song.songName];
		PlayState.isStoryMode = true;
		PlayState.storyPlaylist = playlist;
		PlayState.storyDifficulty = curDifficulty;
		PlayState.storyWeek = curSelected;
		PlayState.campaignScore = 0;
		PlayState.campaignMisses = 0;

		var diffName:String = currentWeekDifficulties[curDifficulty].toLowerCase();
		var diffSuffix:String = (diffName == "normal") ? "" : "-" + diffName;
		for (char in grpWeekCharacters.members)
		{
			if (char != null && char.hasConfirmAnimation)
				char.animation.play('confirm');
		}

		FlxG.sound.play(Paths.sound('confirmMenu'));
		var selectedWeekSprite = grpWeeks.members[curSelected];
		selectedWeekSprite.color = FlxColor.CYAN;
		FlxFlicker.flicker(selectedWeekSprite, 1, 0.06, false, false, function(flick:FlxFlicker)
		{
			PlayState.SONG = Song.loadFromJson(playlist[0].toLowerCase() + diffSuffix, playlist[0].toLowerCase());
			LoadingState.loadAndSwitchState(new PlayState());
		});
	}

	override function destroy()
	{
		// Очистка кэша для предотвращения утечек памяти
		for (sprite in persistentCache)
		{
			if (sprite != null)
				sprite.destroy();
		}
		persistentCache.clear();
		preloadedCharacters.clear();

		if (bgGradientShader != null)
			bgGradientShader = null;

		super.destroy();
	}
}