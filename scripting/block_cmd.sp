#pragma semicolon 1
#pragma newdecls required

KeyValues
	hKeyValues;

ArrayList
	hArray[3];

ConVar
	cvNoSpec;

bool
	bBlockGame[MAXPLAYERS+1];

int
	iHook[MAXPLAYERS+1],
	iHook2[MAXPLAYERS+1];

char
	sFile[PLATFORM_MAX_PATH],
	sIp[MAXPLAYERS+1][16],
	sSteamid[32];

public Plugin myinfo = 
{
	name = "Block CMD",
	author = "Nek.'a 2x2 | ggwp.site ",
	description = "Проверка команд игрока",
	version = "1.0.5",
	url = "https://ggwp.site/"
};

public void OnPluginStart()
{
	cvNoSpec = CreateConVar("sm_bloccmd_nospec", "1", "Перекидывать ли в спеки игроков с запрещенной командой?", _, true, 0.0);
	
	hArray[0] = new ArrayList(ByteCountToCells(64));
	hArray[1] = new ArrayList(ByteCountToCells(64));
	hArray[2] = new ArrayList(ByteCountToCells(64));
	
	char sPath[PLATFORM_MAX_PATH]; Handle hFile;
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/block_cmd.ini");
	
	hKeyValues = new KeyValues("ListCmd");		//Создает новую структуру KeyValues.
	if(!hKeyValues.ImportFromFile(sPath))
		PrintToChatAll("Файл не был загружен [%s]", sPath);
		
	if(!FileExists(sPath))
	{
		hFile = OpenFile(sPath, "w");
		CloseHandle(hFile);
	}
	
	AddCommandListener(Command_JoinTeam, "jointeam");
	
	CheckSettings();
	
	BuildPath(Path_SM, sFile, sizeof(sFile), "logs/block_cmd.log");
	
	RegConsoleCmd("sm_bl", CmdCheckBlock);
	
	AutoExecConfig(true, "block_cmd");
}

public void OnMapStart()
{
	CreateTimer(10.0, CheckClient, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
	CmdList(client);
}

public void OnClientDisconnect(int client)
{
	bBlockGame[client] = false;
}

void CheckSettings()
{
	hKeyValues.Rewind();
	hKeyValues.JumpToKey("BlockCmd", false);

	char sKey[32], sValue[16], sKeyMin[32];
	
	if(hKeyValues.GotoFirstSubKey(false))		//Устанавливает текущую позицию в дереве KeyValues ​​для первого подключа
	{
		do
		{	//Прыгаем на первый раздел BlockCmd
			if(hKeyValues.GetSectionName(sKey, sizeof(sKey)))		//Получает имя текущего раздела.
			{
				if(hKeyValues.GotoFirstSubKey(false))		//Устанавливает текущую позицию в дереве KeyValues ​​для первого подключа
				{
					int iCmdChat;
					do 
					{
						if(hKeyValues.GetSectionName(sKeyMin, sizeof(sKeyMin)))		//Получает имя текущего раздела.
						{
							hKeyValues.GetString(NULL_STRING, sValue, sizeof(sValue));		//	Извлекает строковое значение из ключа KeyValues

							if(!iCmdChat)
							{
								hArray[0].PushString(sKey);	// Добавим в конце массива элемент со значением sCmd
								hArray[1].PushString(sValue);	// Добавим в конце массива элемент со значением sValue минимального значения
							}
							else
							{
								hArray[2].PushString(sValue);	// Добавим в конце массива элемент со значением sValue максимального значения
							}
							iCmdChat++;
						}
						
					} while(hKeyValues.GotoNextKey(false));
					hKeyValues.GoBack();
				}
			}
		} while( hKeyValues.GotoNextKey(false));
	}
	KvRewind(hKeyValues);
	CloseHandle(hKeyValues);
}

Action CheckClient(Handle hTimer)
{
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))
		iHook[i] = 0;
	CheckClientAll();
	return Plugin_Changed;
}

Action CmdCheckBlock(int client, any args)
{
	CheckClientAll();
	
	return Plugin_Changed;
}

void CheckClientAll()
{
	char sConVar[32];

	for(int i = 1; i <=MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i))	//Проверяем всех игроков на сервере
	{
		for(int d; d < GetArraySize(hArray[0]); d++)
		{
			GetArrayString(hArray[0], d, sConVar, sizeof(sConVar));
			QueryClientConVar(i, sConVar, OnConVarQueryFinished, d) == QUERYCOOKIE_FAILED;
		}
	}
}

void CmdList(int client)
{
	char sConVar[32];

	if(!IsFakeClient(client))	//Проверяем всех игроков на сервере
	{
		for(int i; i < GetArraySize(hArray[0]); i++)
		{
			GetArrayString(hArray[0], i, sConVar, sizeof(sConVar));
			QueryClientConVar(client, sConVar, OnConVarQueryFinished, i) == QUERYCOOKIE_FAILED;
		}
	}
}

void OnConVarQueryFinished(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any serial)
{
	if(result == ConVarQuery_NotFound)
		LogError("Игрок [%N] | такой команды [%s] не существует", client, cvarName);
	
	else if(result == ConVarQuery_NotValid)
		LogError("Была найдена консольная команда с тем же именем [%s], но в ней нет convar", client, cvarName);
	
	else if(result == ConVarQuery_Protected)
		LogError("Игрок [%N] | convar [%s] был найден, но он защищен. Сервер не может получить его значение", client, cvarName);
	
	char sConVars[3][64];

	GetArrayString(hArray[0], serial, sConVars[0], sizeof(sConVars[]));		//Достаём из списка проверяемые команды по одной
	GetArrayString(hArray[1], serial, sConVars[1], sizeof(sConVars[]));		//Достаём из списка минимальное значение команды
	GetArrayString(hArray[2], serial, sConVars[2], sizeof(sConVars[]));		//Достаём из списка максимальное значение команды

	//PrintToChatAll("Проверка команды [%s] у клиента [%s] со значением [%s]", sConVars[0], cvarName, cvarValue);
	GetClientAuthId(client, AuthId_Steam2, sSteamid, sizeof(sSteamid));
	GetClientIP(client, sIp[client], sizeof(sIp[]));
	
	// Проверки значений команд из БлокЛист
	switch(GetTypeString(cvarValue))
	{
		//case 0:
		//	LogError("Команда %s использует в качестве значения текст [%s]", cvarName, cvarValue);
		case 0:
		{
			LogToFile(sFile, "Игрок [%N]/[%s]/[%s] использует запрещённое значение команды %s %s, он попытался сжульничать и использовать текст !", client, sIp[client], sSteamid, sConVars[0], cvarValue);
			if(cvNoSpec.BoolValue)
			{
				//KickClient(client, "У вас не допустимое значение [%s %s], разрешенные пределы [%s]/[%s]", sConVars[0], cvarValue, sConVars[1], sConVars[2]);
				bBlockGame[client] = true;
				if(bBlockGame[client] == true)
				{
					iHook[client]++;
					
				}
				iHook2[client] = 1;
				if(bBlockGame[client])
				{
					ChangeClientTeam(client, 1);
					DisplayString(client, sConVars[0], StringToInt(cvarValue), StringToInt(sConVars[1]), StringToInt(sConVars[2]));
				}
			}
		}
		case 1:
		{
			if(StringToFloat(sConVars[1]) > StringToFloat(cvarValue) || StringToFloat(cvarValue) > StringToFloat(sConVars[2]))
			{
				LogToFile(sFile, "Игрок [%N]/[%s]/[%s] использует запрещённое значение команды %s %s, разрешенные пределы [%s]/[%s]", client, sIp[client], sSteamid, sConVars[0], cvarValue, sConVars[1], sConVars[2]);
				if(cvNoSpec.BoolValue)
				{
					//KickClient(client, "У вас не допустимое значение [%s %s], разрешенные пределы [%s]/[%s]", sConVars[0], cvarValue, sConVars[1], sConVars[2]);
					bBlockGame[client] = true;
					if(bBlockGame[client] == true)
					{
						iHook[client]++;
						
					}
					iHook2[client] = 1;
					if(bBlockGame[client])
					{
						ChangeClientTeam(client, 1);
						DisplayPanelFloat(client, sConVars[0], StringToFloat(cvarValue), StringToFloat(sConVars[1]), StringToFloat(sConVars[2]));
						
					}
				}
			}
		}
		
		case 2:
		{
			if(StringToInt(sConVars[1]) > StringToInt(cvarValue) || StringToInt(cvarValue) > StringToInt(sConVars[2]))
			{
				//PrintToChatAll("У игрока [%N] значение [%d], разрешенное минимальное [%d]", client, StringToInt(sConVars[1]), StringToInt(cvarValue));
				LogToFile(sFile, "Игрок [%N]/[%s]/[%s] использует запрещённое значение команды %s %s, разрешенные пределы [%s]/[%s]", client, sIp[client], sSteamid, sConVars[0], cvarValue, sConVars[1], sConVars[2]);
				if(cvNoSpec.BoolValue)
				{
					//KickClient(client, "У вас не допустимое значение [%s %s], разрешенные пределы [%s]/[%s]", sConVars[0], cvarValue, sConVars[1], sConVars[2]);
					bBlockGame[client] = true;
					if(bBlockGame[client] == true)
					{
						iHook[client]++;
						
					}
					iHook2[client] = 1;
					if(bBlockGame[client])
					{
						ChangeClientTeam(client, 1);
						DisplayPanel(client, sConVars[0], StringToInt(cvarValue), StringToInt(sConVars[1]), StringToInt(sConVars[2]));
						
					}
				}
			}
		}
	}
	if(cvNoSpec.BoolValue)
	{
		if(!iHook[client] && iHook2[client] > 0)
		{
			char sText[512];
			Format(sText, sizeof(sText), "Теперь вы [%N] можете играть !", client);
			ShowMOTDPanel(client, "Меню с подсказкой", sText, MOTDPANEL_TYPE_TEXT);
			bBlockGame[client] = false;
			iHook2[client] = 0;
		}
	}
}

void DisplayPanel(int client, char[] sVars, int iValue, int iCvarMin, int iCvarMax)
{
	char sText[512];

	Format(sText, sizeof(sText), "У вас [%N] запрещенное значение команды %s %d\nПеределай [%d]/[%d] И через пару секунд играй!", client, sVars, iValue, iCvarMin, iCvarMax);
	ShowMOTDPanel(client, "Меню с подсказкой", sText, MOTDPANEL_TYPE_TEXT);
}

void DisplayPanelFloat(int client, char[] sVars, float fValue, float fCvarMin, float fCvarMax)
{
	char sText[512];

	Format(sText, sizeof(sText), "У вас [%N] запрещенное значение команды %s %.3f\nПеределай [%.3f]/[%.3f] И через пару секунд играй!", client, sVars, fValue, fCvarMin, fCvarMax);
	ShowMOTDPanel(client, "Меню с подсказкой", sText, MOTDPANEL_TYPE_TEXT);
}

void DisplayString(int client, char[] sVars, int iValue, int iCvarMin, int iCvarMax)
{
	char sText[512];

	Format(sText, sizeof(sText), "У вас [%N] запрещенное значение команды %s является текстом ! Что не допустимо для этой команды\nПеределай [%d]/[%d] И через пару секунд играй!", client, sVars, iValue, iCvarMin, iCvarMax);
	ShowMOTDPanel(client, "Меню с подсказкой", sText, MOTDPANEL_TYPE_TEXT);
}

Action Command_JoinTeam(int client, char[] sCommand, int args)
{
	char sArg[8];
	GetCmdArg(1, sArg, sizeof(sArg));
	//int iNewTeam = StringToInt(sArg);
	int iOldTeam = GetClientTeam(client);

	if(bBlockGame[client] && (iOldTeam == 0 || iOldTeam == 1))
	{
		ChangeClientTeam(client, 1);
		return Plugin_Handled;
	}
	
	return Plugin_Changed;
}

/**
 * types:
 * 0 - string
 * 1 - float
 * 2 - int
 */

int GetTypeString(const char[] string)
{
	int len = strlen(string), i = -1;
	if (22 < len) return 0;
	if (string[0] == 45)
	{
		if (len == 1) return 0;
		i = 0;
	}
	while (string[++i]) if (string[i] < 48 || 57 < string[i]) return string[i] == 46 && 47 < string[++i] && string[i] < 58 ? 1 : 0;
	return 2;
}