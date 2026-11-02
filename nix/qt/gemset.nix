{
  glib2 = {
    dependencies = ["native-package-installer" "pkg-config"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1ka9jmipfa1adf47l8831mflmjz20chiybz6z4s5wbl1gr2dph9j";
      type = "gem";
    };
    version = "4.3.9";
  };
  native-package-installer = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0bvr9q7qwbmg9jfg85r1i5l7d0yxlgp0l2jg62j921vm49mipd7v";
      type = "gem";
    };
    version = "1.1.9";
  };
  pkg-config = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "079fz8vkjrjjmid3k5a6bwp9vssvv3hxm4c8v5121vlmfs65517y";
      type = "gem";
    };
    version = "1.6.6";
  };
  ruby-qt6-qtcore = {
    dependencies = ["ruby-qt6-rice"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "071ja4v5ff3k9iakjssiqf3ydfj7z9zkfd5343dfss6nbz4wb5h6";
      type = "gem";
    };
    version = "6.3.0";
  };
  ruby-qt6-qtgui = {
    dependencies = ["ruby-qt6-qtcore" "ruby-qt6-rice"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1r2bdswkvwm0z9bq6fvapyl25zm5r38vvb4mh5lf2pc5gw3hwg3i";
      type = "gem";
    };
    version = "6.3.0";
  };
  ruby-qt6-qtqml = {
    dependencies = ["ruby-qt6-qtcore" "ruby-qt6-rice"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0i72y4iy9yj3n18kszq5mbk4idvnn4djdcm1vjrr127hpb5cxjk2";
      type = "gem";
    };
    version = "6.3.0";
  };
  ruby-qt6-qtquick = {
    dependencies = ["ruby-qt6-qtcore" "ruby-qt6-qtgui" "ruby-qt6-qtqml" "ruby-qt6-rice"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "09bdqp1slfnaxmm81iwx28cfwrl2a8an9i2y8r7qaraw3vjhv4g8";
      type = "gem";
    };
    version = "6.3.0";
  };
  ruby-qt6-qtquickcontrols2 = {
    dependencies = ["ruby-qt6-qtcore" "ruby-qt6-rice"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "19fnvi7c4r39kcc1krli1gl7wqg60rwp12b884kdz2vzaf8va8dd";
      type = "gem";
    };
    version = "6.3.0";
  };
  ruby-qt6-qtwidgets = {
    dependencies = ["ruby-qt6-qtcore" "ruby-qt6-qtgui" "ruby-qt6-rice"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0dc9p0kal5pd3ib8z46p2cavvk0xmnfrpjrnahkk2ssazllv306v";
      type = "gem";
    };
    version = "6.3.0";
  };
  ruby-qt6-rice = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0aip8kiyb78anjc47zd0jjgjrmjx6gsw0hz45v0x1gdkwj9rbg8n";
      type = "gem";
    };
    version = "6.3.0";
  };
}
