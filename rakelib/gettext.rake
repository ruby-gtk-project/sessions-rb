# frozen_string_literal: true

require "fileutils"

# The translation and packaging build steps, ported from the four go:generate
# lines in po/index.go, the schema step in main.go's build, and the install
# commands in com.pojtinger.felicitas.Sessions.json.
#
# Everything here needs GNU gettext's `msgfmt`/`xgettext` and glib's
# `glib-compile-schemas` at *build* time only; flake.nix puts both in the
# devshell and in the package's nativeBuildInputs, and neither is in the
# runtime closure.
#
# `msgfmt -c --check-format` rather than a bare msgfmt, because upstream's
# catalogues carry `#, c-format` flags and that is the check which stops a
# translator's `%s` typo from crashing the app in one language only.

module SessionsData
  APP_ID = "com.pojtinger.felicitas.Sessions"
  DOMAIN = "sessions"

  PO_DIR = "po"
  DATA_DIR = "data"

  DESKTOP_TEMPLATE = "#{DATA_DIR}/#{APP_ID}.desktop.in"
  DESKTOP_FILE = "#{DATA_DIR}/#{APP_ID}.desktop"
  METAINFO_TEMPLATE = "#{DATA_DIR}/#{APP_ID}.metainfo.xml.in"
  METAINFO_FILE = "#{DATA_DIR}/#{APP_ID}.metainfo.xml"
  GSCHEMA_FILE = "#{DATA_DIR}/#{APP_ID}.gschema.xml"
  POT_FILE = "#{PO_DIR}/#{DOMAIN}.pot"

  # Languages come from LINGUAS rather than from a glob over po/*.po, so a
  # language that loses its catalogue loses it loudly.
  def self.linguas
    File.readlines(File.join(PO_DIR, "LINGUAS"), chomp: true).reject(&:empty?)
  end

  def self.mo_path(lang) = File.join(
    PO_DIR,
    lang,
    "LC_MESSAGES",
    "#{DOMAIN}.mo",
  )

  def self.potfiles
    File.readlines(File.join(PO_DIR, "POTFILES.in"), chomp: true)
      .reject { |line| line.empty? || line.start_with?("#") }
  end

  # The ITS rules that teach xgettext which elements of an AppStream component
  # and a GSettings schema are translatable. Upstream hardcodes
  # /usr/share/gettext/its, which is where a distribution puts both; they are
  # shipped by two different packages, though — metainfo.its by gettext and
  # gschema.its by glib — so on a system that keeps packages apart they are in
  # two directories and each rule is searched for by name.
  def self.its_rule(name)
    its_directories.map { |dir| File.join(dir, name) }.find { |path| File.file?(path) } ||
      raise("could not find #{name}; set GETTEXT_ITS_DIR to the directory holding it")
  end

  def self.its_directories
    [
      *ENV["GETTEXT_ITS_DIR"],
      *data_roots.product(["gettext/its", "gettext-1.0/its"]).map { |root, its| File.join(root, its) },
      "/usr/share/gettext/its",
      "/usr/local/share/gettext/its",
    ]
  end

  # Every share/ directory this system is willing to look in: the ones holding
  # the tools on PATH, and the XDG search path xgettext itself consults.
  def self.data_roots
    [
      *ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).filter_map do |bin|
        if File.executable?(File.join(bin, "msgfmt")) || File.executable?(File.join(bin, "glib-compile-schemas"))
          File.expand_path("../share", bin)
        end
      end,
      *ENV.fetch("XDG_DATA_DIRS", "").split(File::PATH_SEPARATOR),
    ].uniq
  end

  def self.install_file(source, destination)
    FileUtils.mkdir_p(File.dirname(destination))
    FileUtils.install(source, destination, mode: 0o644)
  end
end

namespace :gettext do
  desc "Compile one .mo per language into po/<lang>/LC_MESSAGES/sessions.mo"
  task :mo do
    SessionsData.linguas.each do |lang|
      po = File.join(SessionsData::PO_DIR, "#{lang}.po")
      unless File.exist?(po)
        raise "#{po} is named in po/LINGUAS but does not exist"
      end

      FileUtils.mkdir_p(File.dirname(SessionsData.mo_path(lang)))
      sh(
        "msgfmt",
        "-c",
        "--check-format",
        "-o",
        SessionsData.mo_path(lang),
        po,
      )
    end
  end

  desc "Merge po/ into the .desktop and metainfo files (msgfmt --template)"
  task :data do
    # `--desktop --template` writes Name[de]=, Comment[fr]= and the localised
    # Keywords lines into the desktop entry; `--xml -L metainfo --template`
    # writes <summary xml:lang="de"> and the localised <description> and
    # <caption> elements into the AppStream component. Without these two steps
    # the twelve msgids that live in these two files ship as English in all
    # twenty-six languages, however complete po/ is.
    sh(

      "msgfmt",

      "--desktop",

      "--template",

      SessionsData::DESKTOP_TEMPLATE,
      "-d",

      SessionsData::PO_DIR,

      "-o",

      SessionsData::DESKTOP_FILE,

    )
    sh(

      "msgfmt",

      "--xml",

      "-L",

      "metainfo",

      "--template",

      SessionsData::METAINFO_TEMPLATE,
      "-d",

      SessionsData::PO_DIR,

      "-o",

      SessionsData::METAINFO_FILE,

    )
  end

  desc "Re-extract po/sessions.pot from the files in po/POTFILES.in"
  task :pot do
    # GNU xgettext has no Ruby mode — upstream passes --language=C++ for its
    # Go, which would miss every single-quoted Ruby string — so the Ruby pass
    # uses rxgettext from the gettext gem, which parses Ruby properly and
    # knows the whole marker set. The gem's parser drops translator comments
    # unless asked, hence --add-comments.
    #
    # The three non-Ruby sources each need their own extraction mode, so each
    # gets a pass of its own, joined onto the first with -j.
    sh(

      "rxgettext",

      "--add-comments=TRANSLATORS:",
      "--output",

      SessionsData::POT_FILE,
      *SessionsData.potfiles.grep(/\.rb\z|\Aexe\//),

    )
    sh(

      "xgettext",

      "--language=Desktop",

      "--keyword=Name",

      "--keyword=Comment",
      "--keyword=Keywords",

      "--add-comments=TRANSLATORS:",

      "--omit-header",
      "-j",

      "-o",

      SessionsData::POT_FILE,

      SessionsData::DESKTOP_TEMPLATE,

    )
    sh(

      "xgettext",

      "--its=#{SessionsData.its_rule("metainfo.its")}",

      "--omit-header",
      "-j",

      "-o",

      SessionsData::POT_FILE,

      SessionsData::METAINFO_TEMPLATE,

    )
    sh(

      "xgettext",

      "--its=#{SessionsData.its_rule("gschema.its")}",

      "--omit-header",
      "-j",

      "-o",

      SessionsData::POT_FILE,

      SessionsData::GSCHEMA_FILE,

    )
  end

  # WARNING: this task rewrites all 26 catalogues, and running it is not
  # routine.
  #
  # Every po/*.po is `cmp`-identical to upstream's, which is the cheapest proof
  # available that no donated string has been touched. `msgmerge --update`
  # rewrites each file's `#:` reference lines from upstream's
  # `../assets/resources/*` and `../internal/components/*` to this port's
  # `data/` and `lib/` paths, and that property is gone the first time it runs
  # — in all 26 files at once, in a diff nobody can review for content.
  #
  # It would also have added four empty-msgstr entries to all 26, because the
  # port's .pot carried four msgids of its own (the About dialog's link rows).
  # Those are deleted and the .pot is back to upstream's 33 msgids, so a merge
  # today would add no entry — but it would still churn the references.
  # TRANSLATION_PARITY.md records the same warning.
  desc "Merge a regenerated .pot into every .po (the only thing that edits them)"
  task merge: :pot do
    # po/*.po are donated work. Nothing else in this repository writes to them.
    SessionsData.linguas.each do |lang|
      sh(

        "msgmerge",

        "--update",

        "--backup=none",
        File.join(SessionsData::PO_DIR, "#{lang}.po"),

        SessionsData::POT_FILE,

      )
    end
  end
end

namespace :schema do
  desc "Compile the GSettings schema into data/gschemas.compiled"
  task :compile do
    sh("glib-compile-schemas", "--strict", SessionsData::DATA_DIR)
  end
end

desc "Build everything a desktop needs: catalogues, merged data files, schema"
task build_data: ["gettext:mo", "gettext:data", "schema:compile"]

desc "Install the app's data files under PREFIX (default /usr/local)"
task install_data: :build_data do
  root = File.join(ENV.fetch("DESTDIR", ""), ENV.fetch("PREFIX", "/usr/local"))

  # The same destinations the Flatpak manifest installs to, which are the ones
  # a desktop actually reads: without them the app has no launcher, no
  # AppStream entry, no icon, no settings schema and no translations.
  SessionsData.install_file(
    SessionsData::METAINFO_FILE,
    File.join(root, "share/metainfo", "#{SessionsData::APP_ID}.metainfo.xml"),
  )
  SessionsData.install_file(
    SessionsData::DESKTOP_FILE,
    File.join(root, "share/applications", "#{SessionsData::APP_ID}.desktop"),
  )
  SessionsData.install_file(
    File.join(SessionsData::DATA_DIR, "#{SessionsData::APP_ID}.svg"),
    File.join(root, "share/icons/hicolor/scalable/apps", "#{SessionsData::APP_ID}.svg"),
  )
  SessionsData.install_file(
    File.join(SessionsData::DATA_DIR, "#{SessionsData::APP_ID}-symbolic.svg"),
    File.join(root, "share/icons/hicolor/symbolic/apps", "#{SessionsData::APP_ID}-symbolic.svg"),
  )
  SessionsData.install_file(
    SessionsData::GSCHEMA_FILE,
    File.join(root, "share/glib-2.0/schemas", "#{SessionsData::APP_ID}.gschema.xml"),
  )
  SessionsData.linguas.each do |lang|
    SessionsData.install_file(
      SessionsData.mo_path(lang),
      File.join(
        root,
        "share/locale",
        lang,
        "LC_MESSAGES",
        "#{SessionsData::DOMAIN}.mo",
      ),
    )
  end

  # The two caches a desktop reads instead of the files, so a fresh install is
  # visible without a re-login.
  sh("glib-compile-schemas", File.join(root, "share/glib-2.0/schemas"))
  sh("update-desktop-database", File.join(root, "share/applications"))
end
