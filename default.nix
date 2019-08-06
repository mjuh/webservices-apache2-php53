with import <nixpkgs> {
  overlays = [
    (import (builtins.fetchGit { url = "git@gitlab.intr:_ci/nixpkgs.git"; ref = "master"; }))
  ];
};

let

inherit (builtins) concatMap getEnv toJSON;
inherit (dockerTools) buildLayeredImage;
inherit (lib) concatMapStringsSep firstNChars flattenSet dockerRunCmd buildPhpPackage mkRootfs;
inherit (lib.attrsets) collect isDerivation;
inherit (stdenv) mkDerivation;

  locale = glibcLocales.override {
      allLocales = false;
      locales = ["en_US.UTF-8/UTF-8"];
  };

sh = dash.overrideAttrs (_: rec {
  postInstall = ''
    ln -s dash "$out/bin/sh"
  '';
});

  zendguard = stdenv.mkDerivation rec {
      name = "zend-guard-53";
      src =  fetchurl {
          url = "https://downloads.zend.com/guard/5.5.0/ZendGuardLoader-php-5.3-linux-glibc23-x86_64.tar.gz";
          sha256 = "6982877fdd66ecdd684591a82c5aa702a09d92aac5a2c87e9781d40b76a30098";
      };
      installPhase = ''
                  mkdir -p  $out/
                  tar zxvf  ${src} -C $out/ ZendGuardLoader-php-5.3-linux-glibc23-x86_64/php-5.3.x/ZendGuardLoader.so
      '';
  };

  pcre831 = stdenv.mkDerivation rec {
      name = "pcre-8.31";
      src = fetchurl {
          url = "https://ftp.pcre.org/pub/pcre/${name}.tar.bz2";
          sha256 = "0g4c0z4h30v8g8qg02zcbv7n67j5kz0ri9cfhgkpwg276ljs0y2p";
      };
      outputs = [ "out" ];
      configureFlags = ''
          --enable-jit
      '';
  };

  libjpeg130 = stdenv.mkDerivation rec {
     name = "libjpeg-turbo-1.3.0";
     src = fetchurl {
         url = "mirror://sourceforge/libjpeg-turbo/${name}.tar.gz";
         sha256 = "0d0jwdmj3h89bxdxlwrys2mw18mqcj4rzgb5l2ndpah8zj600mr6";
     };
     buildInputs = [ nasm ];
     doCheck = true;
     checkTarget = "test";
 };

  libpng12 = stdenv.mkDerivation rec {
     name = "libpng-1.2.59";
     src = fetchurl {
        url = "mirror://sourceforge/libpng/${name}.tar.xz";
        sha256 = "b4635f15b8adccc8ad0934eea485ef59cc4cae24d0f0300a9a941e51974ffcc7";
     };
     buildInputs = [ zlib ];
     doCheck = true;
     checkTarget = "test";
  };

  connectorc = stdenv.mkDerivation rec {
     name = "mariadb-connector-c-${version}";
     version = "6.1.0";

     src = fetchurl {
         url = "https://downloads.mysql.com/archives/get/file/mysql-connector-c-6.1.0-src.tar.gz";
         sha256 = "0cifddg0i8zm8p7cp13vsydlpcyv37mz070v6l2mnvy0k8cng2na";
         name   = "mariadb-connector-c-${version}-src.tar.gz";
     };

  # outputs = [ "dev" "out" ]; FIXME: cmake variables don't allow that < 3.0
     cmakeFlags = [
            "-DWITH_EXTERNAL_ZLIB=ON"
            "-DMYSQL_UNIX_ADDR=/run/mysqld/mysqld.sock"
     ];

  # The cmake setup-hook uses $out/lib by default, this is not the case here.
     preConfigure = stdenv.lib.optionalString stdenv.isDarwin ''
             cmakeFlagsArray+=("-DCMAKE_INSTALL_NAME_DIR=$out/lib/mariadb")
     '';

     nativeBuildInputs = [ cmake ];
     propagatedBuildInputs = [ openssl zlib ];
     buildInputs = [ libiconv ];
     enableParallelBuilding = true;
  };

 imagemagick68 = stdenv.mkDerivation rec {
  version = "6.8.8-7";
    name = "ImageMagick-${version}";

  src = fetchurl {
    url = "https://mirror.sobukus.de/files/src/imagemagick/${name}.tar.xz";
    sha256 = "1x5jkbrlc10rx7vm344j7xrs74c80xk3n1akqx8w5c194fj56mza";
  };

  enableParallelBuilding = true;

  configureFlags = ''
    --with-gslib
    --with-frozenpaths
    ${if librsvg != null then "--with-rsvg" else ""}
  '';

  buildInputs =
    [ pkgconfig bzip2 fontconfig freetype libjpeg libpng libtiff libxml2 zlib librsvg
      libtool jasper
    ];

  postInstall = ''(cd "$out/include" && ln -s ImageMagick* ImageMagick)'';
 };

 buildPhp53Package = args: buildPhpPackage ({ php = php53; } // args);


php53Packages = {
  timezonedb = buildPhp53Package {
    name = "timezonedb";
    version = "2019.1";
    sha256 = "0rrxfs5izdmimww1w9khzs9vcmgi1l90wni9ypqdyk773cxsn725";
  };

  dbase = buildPhp53Package {
      name = "dbase";
      version = "5.1.0";
      sha256 = "15vs527kkdfp119gbhgahzdcww9ds093bi9ya1ps1r7gn87s9mi0";
  };

  intl = buildPhp53Package {
      name = "intl";
      version = "3.0.0";
      sha256 = "11sz4mx56pc1k7llgbbpz2i6ls73zcxxdwa1d0jl20ybixqxmgc8";
      inputs = [ icu58 ];
  };

  zendopcache = buildPhp53Package {
      name = "zendopcache";
      version = "7.0.5";
      sha256 = "1h79x7n5pylbc08cxl44fvbi1a1592n0w0mm847jirkqrhxs5r68";
  };

  imagick = buildPhp53Package {
      name = "imagick";
      version = "3.1.2";
      sha256 = "528769ac304a0bbe9a248811325042188c9d16e06de16f111fee317c85a36c93";
      inputs = [ pkgconfig imagemagick68 pcre ];
      configureFlags = [ "--with-imagick=${imagemagick68}" ];
  };
};

  rootfs = mkRootfs {
      name = "apache2-php53-rootfs";
      src = ./rootfs;
      inherit curl coreutils findutils apacheHttpdmpmITK apacheHttpd mjHttpErrorPages php53 postfix s6 execline zendguard connectorc mjperl5Packages ;
      ioncube = ioncube.v53;
      s6PortableUtils = s6-portable-utils;
      s6LinuxUtils = s6-linux-utils;
      mimeTypes = mime-types;
      libstdcxx = gcc-unwrapped.lib;
  };

dockerArgHints = {
    init = false;
    read_only = true;
    network = "host";
    environment = { HTTPD_PORT = "$SOCKET_HTTP_PORT";  PHP_SECURITY = "${rootfs}/etc/phpsec/$SECURITY_LEVEL"; };
    tmpfs = [
      "/tmp:mode=1777"
      "/run/bin:exec,suid"
      "/run/php.d:mode=644"
    ];
    ulimits = [
      { name = "stack"; hard = -1; soft = -1; }
    ];
    security_opt = [ "apparmor:unconfined" ];
    cap_add = [ "SYS_ADMIN" ];
    volumes = [
      ({ type = "bind"; source =  "$SITES_CONF_PATH" ; target = "/read/sites-enabled"; read_only = true; })
      ({ type = "bind"; source =  "/etc/passwd" ; target = "/etc/passwd"; read_only = true; })
      ({ type = "bind"; source =  "/etc/group" ; target = "/etc/group"; read_only = true; })
      ({ type = "bind"; source = "/opcache"; target = "/opcache"; })
      ({ type = "bind"; source = "/home"; target = "/home"; })
      ({ type = "bind"; source = "/opt/postfix/spool/maildrop"; target = "/var/spool/postfix/maildrop"; })
      ({ type = "bind"; source = "/opt/postfix/spool/public"; target = "/var/spool/postfix/public"; })
      ({ type = "bind"; source = "/opt/postfix/lib"; target = "/var/lib/postfix"; })
      ({ type = "tmpfs"; target = "/run"; })
    ];
  };

gitAbbrev = firstNChars 8 (getEnv "GIT_COMMIT");

in 

pkgs.dockerTools.buildLayeredImage rec {
  maxLayers = 124;
  name = "docker-registry.intr/webservices/apache2-php53";
  tag = if gitAbbrev != "" then gitAbbrev else "latest";
  contents = [
    rootfs
    tzdata
    locale
    postfix
    sh
    coreutils
    perl
         perlPackages.TextTruncate
         perlPackages.TimeLocal
         perlPackages.PerlMagick
         perlPackages.commonsense
         perlPackages.Mojolicious
         perlPackages.base
         perlPackages.libxml_perl
         perlPackages.libnet
         perlPackages.libintl_perl
         perlPackages.LWP
         perlPackages.ListMoreUtilsXS
         perlPackages.LWPProtocolHttps
         perlPackages.DBI
         perlPackages.DBDmysql
         perlPackages.CGI
         perlPackages.FilePath
         perlPackages.DigestPerlMD5
         perlPackages.DigestSHA1
         perlPackages.FileBOM
         perlPackages.GD
         perlPackages.LocaleGettext
         perlPackages.HashDiff
         perlPackages.JSONXS
         perlPackages.POSIXstrftimeCompiler
         perlPackages.perl
  ] ++ collect isDerivation php53Packages;
  config = {
    Entrypoint = [ "${rootfs}/init" ];
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=${tzdata}/share/zoneinfo"
      "LOCALE_ARCHIVE_2_27=${locale}/lib/locale/locale-archive"
      "LC_ALL=en_US.UTF-8"
    ];
    Labels = flattenSet rec {
      ru.majordomo.docker.arg-hints-json = builtins.toJSON dockerArgHints;
      ru.majordomo.docker.cmd = dockerRunCmd dockerArgHints "${name}:${tag}";
      ru.majordomo.docker.exec.reload-cmd = "${apacheHttpd}/bin/httpd -d ${rootfs}/etc/httpd -k graceful";
    };
  };
}
