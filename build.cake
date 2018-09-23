///////////////////////////////////////////////////////////////////////////////
// ARGUMENTS
///////////////////////////////////////////////////////////////////////////////

var target = Argument("target", "Pack");

///////////////////////////////////////////////////////////////////////////////
// SETUP / TEARDOWN
///////////////////////////////////////////////////////////////////////////////

Setup(ctx =>
{
    EnsureDirectoryExists("./build");
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
    CopyFile("./LICENSE", "./src/LICENSE.txt");
    CopyFile("./README.md", "./src/README.md");
    Zip("./src", "./build/scripts.zip");
    DeleteFile("./src/LICENSE.txt");
    DeleteFile("./src/README.md");
});

Task("Pack")
.IsDependentOn("Zip")
.Does(() => {
    var now = DateTime.UtcNow;
    var secondsToday = (long)now.TimeOfDay.TotalSeconds;
    var daysSince2000 = (long)(now - new DateTime(2000, 01, 01, 00, 00, 00, DateTimeKind.Utc)).TotalDays;
    var versionStr = $"0.4.{daysSince2000}.{secondsToday}";

    var settings = new ChocolateyPackSettings {
        Id                       = "obs-studio-wiiplayer2-scripts",
        Title                    = "DarkLink's Scripts for OBS Studio",
        Version                  = versionStr,
        Authors                  = new[] { "WiiPlayer2" },
        Owners                   = new[] { "WiiPlayer2" },
        Summary                  = "DarkLink's Scripts for OBS Studio",
        Description              = System.IO.File.ReadAllText("./README.md"),
        ProjectUrl               = new Uri("https://github.com/WiiPlayer2/obs-scripts"),
        PackageSourceUrl         = new Uri("https://github.com/WiiPlayer2/obs-scripts"),
        ProjectSourceUrl         = new Uri("https://github.com/WiiPlayer2/obs-scripts"),
        DocsUrl                  = new Uri("https://github.com/WiiPlayer2/obs-scripts"),
        MailingListUrl           = new Uri("https://github.com/WiiPlayer2/obs-scripts"),
        BugTrackerUrl            = new Uri("https://github.com/WiiPlayer2/obs-scripts"),
        ReleaseNotes             = new [] { "https://github.com/WiiPlayer2/obs-scripts/releases" },
        Tags                     = new [] { "obs", "scripts", "filter" },
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
            new ChocolateyNuSpecContent { Source = "LICENSE*", Target = "tools" },
            new ChocolateyNuSpecContent { Source = "cake/choco/VERIFICATION.txt", Target = "tools" },
            new ChocolateyNuSpecContent { Source = "cake/choco/chocolateyInstall.ps1", Target = "tools" },
            new ChocolateyNuSpecContent { Source = "build/scripts.zip", Target = "data" },
        },
        OutputDirectory = "./build",
    };
    ChocolateyPack(settings);

    System.IO.File.WriteAllText("./build/version.txt", versionStr);
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
