{ nixpkgs }:

with nixpkgs;

let
  inherit (builtins) concatMap getEnv toJSON;
  inherit (dockerTools) buildLayeredImage;
  inherit (lib) concatMapStringsSep firstNChars flattenSet dockerRunCmd mkRootfs;
  inherit (lib.attrsets) collect isDerivation;
  inherit (stdenv) mkDerivation;

  php53DockerArgHints = lib.phpDockerArgHints { php = php53; };

  rootfs = mkRootfs {
    name = "apache2-rootfs-php53";
    src = ./rootfs;
    zendguard = zendguard.loader-php53;
    zendopcache = php53Packages.zendopcache;
    inherit zlib curl coreutils findutils apacheHttpdmpmITK apacheHttpd
      s6 execline php53 logger;
    mjHttpErrorPages = mj-http-error-pages;
    postfix = sendmail;
    mjperl5Packages = mjperl5lib;
    ioncube = ioncube.v53;
    s6PortableUtils = s6-portable-utils;
    s6LinuxUtils = s6-linux-utils;
    mimeTypes = mime-types;
    libstdcxx = gcc-unwrapped.lib;
  };

in

pkgs.dockerTools.buildLayeredImage rec {
  name = "docker-registry.intr/webservices/apache2-php53";
  tag = "latest";
  contents = [
    rootfs
    tzdata
    apacheHttpd
    locale
    sendmail
    sh
    coreutils
    libjpeg_turbo
    jpegoptim
    (optipng.override { inherit libpng; })
    imagemagick
    gifsicle
    nss-certs.unbundled
    zip
    gcc-unwrapped.lib
    glibc
    zlib
    mariadbConnectorC
    logger
    perl520
  ]
  ++ collect isDerivation php53Packages
  ++ collect isDerivation mjperl5Packages;
  config = {
    Entrypoint = [ "${rootfs}/init" ];
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=${tzdata}/share/zoneinfo"
      "LOCALE_ARCHIVE_2_27=${locale}/lib/locale/locale-archive"
      "LOCALE_ARCHIVE=${locale}/lib/locale/locale-archive"
      "LC_ALL=en_US.UTF-8"
      "LD_PRELOAD=${jemalloc}/lib/libjemalloc.so"
      "PERL5LIB=${mjPerlPackages.PERL5LIB}"
    ];
    Labels = flattenSet rec {
      ru.majordomo.docker.arg-hints-json = builtins.toJSON php53DockerArgHints;
      ru.majordomo.docker.cmd = dockerRunCmd php53DockerArgHints "${name}:${tag}";
      ru.majordomo.docker.exec.reload-cmd = "${apacheHttpd}/bin/httpd -d ${rootfs}/etc/httpd -k graceful";
    };
  };
  extraCommands = ''
    set -xe
    ls
    mkdir -p etc
    mkdir -p bin
    chmod u+w usr
    mkdir -p usr/local
    mkdir -p opt
    ln -s ${php53} opt/php53
    ln -s /bin usr/sbin
    ln -s /bin usr/local/bin
    mkdir tmp
    chmod 1777 tmp
  '';
}
