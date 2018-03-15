///////////////////////////////////////////////////////////////////////////////
// ARGUMENTS
///////////////////////////////////////////////////////////////////////////////

var target = Argument("target", "Pack");
var configuration = Argument("configuration", "Release");

///////////////////////////////////////////////////////////////////////////////
// SETUP / TEARDOWN
///////////////////////////////////////////////////////////////////////////////

Setup(ctx =>
{
   CreateDirectory("./build");
});

Teardown(ctx =>
{
   Information("Finished running tasks.");
});

///////////////////////////////////////////////////////////////////////////////
// TASKS
///////////////////////////////////////////////////////////////////////////////

Task("Clean")
.Does(() => {
    CleanDirectory("./build");
});

Task("Zip")
.IsDependentOn("Clean")
.Does(() => {
    Zip("./src", "./build/scripts.zip");
});

Task("Pack")
.IsDependentOn("Zip")
.Does(() => {
    var now = DateTime.UtcNow;
    var secondsToday = (long)now.TimeOfDay.TotalSeconds;
    var daysSince2000 = (long)(now - new DateTime(2000, 01, 01, 00, 00, 00, DateTimeKind.Utc)).TotalDays;
    
    var settings = new ChocolateyPackSettings {
        Id                       = "obs-studio-wiiplayer2-scripts",
        Title                    = "DarkLink's Scripts for OBS Studio",
        Version                  = $"0.0.{daysSince2000}.{secondsToday}",
        Authors                  = new[] { "WiiPlayer2" },
        Owners                   = new[] { "WiiPlayer2" },
        Summary                  = "DarkLink's Scripts for OBS Studio",
        Description              = "DarkLink's Scripts for OBS Studio",
        ProjectUrl               = new Uri("https://github.com/WiiPlayer2/obs-scripts"),
        PackageSourceUrl         = new Uri("https://github.com/WiiPlayer2/obs-scripts"),
        ProjectSourceUrl         = new Uri("https://github.com/WiiPlayer2/obs-scripts"),
        DocsUrl                  = new Uri("https://github.com/WiiPlayer2/obs-scripts"),
        MailingListUrl           = new Uri("https://github.com/WiiPlayer2/obs-scripts"),
        BugTrackerUrl            = new Uri("https://github.com/WiiPlayer2/obs-scripts"),
        Tags                     = new[] { "obs", "scripts", "filter" },
        Copyright                = $"WiiPlayer2 / DarkLink (c) {now.Year}",
        LicenseUrl               = new Uri("https://github.com/WiiPlayer2/obs-scripts/blob/master/LICENSE"),
        RequireLicenseAcceptance = false,
        Debug                    = false,
        Verbose                  = false,
        Force                    = false,
        Noop                     = false,
        LimitOutput              = false,
        ExecutionTimeout         = 13,
        AllowUnofficial          = false,
        Dependencies             = new [] {
            new ChocolateyNuSpecDependency { Id = "obs-studio" },
        },
        Files = new [] {
            new ChocolateyNuSpecContent { Source = "cake/choco/chocolateyInstall.ps1", Target = "tools" },
            new ChocolateyNuSpecContent { Source = "build/scripts.zip", Target = "data" },
        },
        OutputDirectory = "./build",
    };
    ChocolateyPack(settings);
});

Task("Publish")
.IsDependentOn("Pack")
.Does(() => {
    var packages = GetFiles("./build/*.nupkg");
    ChocolateyPush(packages, new ChocolateyPushSettings {
        Source           = "https://push.chocolatey.org/",
        Debug            = false,
        Verbose          = false,
        Force            = false,
        Noop             = false,
        LimitOutput      = false,
        ExecutionTimeout = 300,
        AllowUnofficial  = false
    });
});

RunTarget(target);
