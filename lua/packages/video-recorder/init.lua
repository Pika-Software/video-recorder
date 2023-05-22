require( "packages/glua-extensions", "https://github.com/Pika-Software/glua-extensions" )

local packageName = gpm.Package:GetIdentifier()
local CreateClientConVar = CreateClientConVar
local FrameTime = FrameTime
local logger = gpm.Logger
local surface = surface
local file = file
local hook = hook

local quality = CreateClientConVar( "recorder_quality", "80", true, false, "Recording quality from 5 to 100%", 5, 100 )
local audio = CreateClientConVar( "recorder_audio", "1", true, false, "Is it worth it to record the sound?", 0, 1 )
local fps = CreateClientConVar( "recorder_fps", "30", true, false, "FPS recording, it is highly not recommended to change!", 15, 75 )
local upload = CreateClientConVar( "recorder_imgur", "0", true, false, "Upload videos to Imgur? (this requires a ClientID and additional package)", 0, 1 )

local matRecording = Material( "gmod/recording.png", "smooth mips" )
local linkColor = Color( 0, 200, 255 )

local function stop()
    if not iVideoWriter then return end
    hook.Remove( "PostRenderVGUI", packageName )
    iVideoWriter:Finish()
    iVideoWriter = nil

    if fpsLimit then
        RunConsoleCommand( "fps_max", fpsLimit )
        fpsLimit = nil
    end

    if fileName then

        local text = "Video saved in 'videos/" .. fileName .. ".mp4"
        notification.AddLegacy( text, NOTIFY_GENERIC, 5 )
        logger:Info( text )

        if upload:GetBool() and type( imgur ) == "table" then
            file.AsyncRead( "videos/" .. fileName .. ".webm", "GAME" ):Then( function( result )
                imgur.Upload( result.fileContent, "video" ):Then( function( result )
                    chat.AddText( logger:GetColor(), packageName, logger:GetTextColor(), ": Video uploaded to Imgur, link: ", linkColor, result.link .. "mp4" )
                end )
            end )
        end

        fileName = nil
    end
end

local function start()
    if iVideoWriter then
        stop()
        return
    end

    local time = SysTime()
    if lastRecord and time - lastRecord < 1 then return end
    lastRecord = time

    if not fileName then
        fileName = game.GetMap() .. os.date( "-%H%M%S-%d%m%Y" )
    end

    if not fpsLimit then
        fpsLimit = cvars.String( "fps_max", 75 )
    end

    local options = {
        ["container"] = "webm",
        ["audio"] = "vorbis",
        ["lockfps"] = true,
        ["video"] = "vp8"
    }

    options.name = fileName
    options.quality = quality:GetInt()
    options.fps = fps:GetInt()

    options.bitrate = 500
    options.width = 1280
    options.height = 720

    iVideoWriter, err = video.Record( options )

    if not iVideoWriter then
        logger:Error( err )
        return
    end

    iVideoWriter:SetRecordSound( audio:GetBool() )

    local screenPercent = math.min( ScrW(), ScrH() ) / 100
    local width, height = screenPercent * 30, screenPercent * 15
    local x, y = ScrW() - width, 0

    hook.Add( "PostRenderVGUI", packageName, function()
        iVideoWriter:AddFrame( FrameTime(), true )

        surface.SetDrawColor( 255, 255, 255 )
        surface.SetMaterial( matRecording )
        surface.DrawTexturedRect( x, y, width, height )
    end )

end

hook.Add( "OnScreenSizeChanged", packageName, stop )
concommand.Add( "recorder_start", start )
concommand.Add( "recorder_stop", stop )
