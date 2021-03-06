{ vimUtils, vim_configurable, writeText, neovim, vimPlugins
, lib, fetchFromGitHub, neovimUtils, wrapNeovimUnstable
, neovim-unwrapped
, fetchFromGitLab
, pkgs
}:
let
  inherit (vimUtils) buildVimPluginFrom2Nix;
  inherit (neovimUtils) makeNeovimConfig;

  packages.myVimPackage.start = with vimPlugins; [ vim-nix ];

  plugins = with vimPlugins; [
    {
      plugin = vim-obsession;
      config = ''
        map <Leader>$ <Cmd>Obsession<CR>
      '';
    }
  ];

  nvimConfNix = makeNeovimConfig {
    inherit plugins;
    customRC = ''
      " just a comment
    '';
  };

  nvimConfDontWrap = makeNeovimConfig {
    inherit plugins;
    customRC = ''
      " just a comment
    '';
  };

  wrapNeovim2 = suffix: config:
    wrapNeovimUnstable neovim-unwrapped (config // {
      extraName = suffix;
    });

  nmt = fetchFromGitLab {
    owner = "rycee";
    repo = "nmt";
    rev = "d2cc8c1042b1c2511f68f40e2790a8c0e29eeb42";
    sha256 = "1ykcvyx82nhdq167kbnpgwkgjib8ii7c92y3427v986n2s5lsskc";
  };

  runTest = neovim-drv: buildCommand:
    pkgs.runCommandLocal "test-${neovim-drv.name}" ({
      nativeBuildInputs = [ ];
      meta.platforms = neovim-drv.meta.platforms;
    }) (''
      source ${nmt}/bash-lib/assertions.sh
      vimrc="${writeText "init.vim" neovim-drv.initRc}"
      vimrcGeneric="$out/patched.vim"
      mkdir $out
      ${pkgs.perl}/bin/perl -pe "s|\Q$NIX_STORE\E/[a-z0-9]{32}-|$NIX_STORE/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee-|g" < "$vimrc" > "$vimrcGeneric"
    '' + buildCommand);

in
  pkgs.recurseIntoAttrs (
rec {
  vim_empty_config = vimUtils.vimrcFile { beforePlugins = ""; customRC = ""; };

  ### neovim tests
  ##################
  nvim_with_plugins = wrapNeovim2 "-with-plugins" nvimConfNix;

  nvim_via_override = neovim.override {
    extraName = "-via-override";
    configure = {
      packages.foo.start = [ vimPlugins.ale ];
      customRC = ''
        :help ale
      '';
    };
  };


  # nixpkgs should detect that no wrapping is necessary
  nvimShouldntWrap = wrapNeovim2 "-should-not-wrap" nvimConfNix;


  # this will generate a neovimRc content but we disable wrapping
  nvimDontWrap = wrapNeovim2 "-dont-wrap" (makeNeovimConfig {
    wrapRc = false;
    customRC = ''
      " this shouldn't trigger the creation of an init.vim
    '';
  });

  nvim_dontwrap-test = runTest nvimDontWrap ''
      ! grep "-u" ${nvimDontWrap}/bin/nvim
  '';

  nvim_via_override-test = runTest nvim_via_override ''
      assertFileContent \
        "$vimrcGeneric" \
        "${./neovim-override.vim}"
  '';

  ### vim tests
  ##################
  vim_with_vim2nix = vim_configurable.customize {
    name = "vim"; vimrcConfig.vam.pluginDictionaries = [ "vim-addon-vim2nix" ];
  };

  # test cases:
  test_vim_with_vim_nix_using_vam = vim_configurable.customize {
   name = "vim-with-vim-addon-nix-using-vam";
    vimrcConfig.vam.pluginDictionaries = [{name = "vim-nix"; }];
  };

  test_vim_with_vim_nix_using_pathogen = vim_configurable.customize {
    name = "vim-with-vim-addon-nix-using-pathogen";
    vimrcConfig.pathogen.pluginNames = [ "vim-nix" ];
  };

  test_vim_with_vim_nix_using_plug = vim_configurable.customize {
    name = "vim-with-vim-addon-nix-using-plug";
    vimrcConfig.plug.plugins = with vimPlugins; [ vim-nix ];
  };

  test_vim_with_vim_nix = vim_configurable.customize {
    name = "vim-with-vim-addon-nix";
    vimrcConfig.packages.myVimPackage.start = with vimPlugins; [ vim-nix ];
  };

  # only neovim makes use of `requiredPlugins`, test this here
  test_nvim_with_vim_nix_using_pathogen = neovim.override {
    configure.pathogen.pluginNames = [ "vim-nix" ];
  };

  # regression test for https://github.com/NixOS/nixpkgs/issues/53112
  # The user may have specified their own plugins which may not be formatted
  # exactly as the generated ones. In particular, they may not have the `pname`
  # attribute.
  test_vim_with_custom_plugin = vim_configurable.customize {
    name = "vim_with_custom_plugin";
    vimrcConfig.vam.knownPlugins =
      vimPlugins // ({
        vim-trailing-whitespace = buildVimPluginFrom2Nix {
          name = "vim-trailing-whitespace";
          src = fetchFromGitHub {
            owner = "bronson";
            repo = "vim-trailing-whitespace";
            rev = "4c596548216b7c19971f8fc94e38ef1a2b55fee6";
            sha256 = "0f1cpnp1nxb4i5hgymjn2yn3k1jwkqmlgw1g02sq270lavp2dzs9";
          };
          # make sure string dependencies are handled
          dependencies = [ "vim-nix" ];
        };
      });
    vimrcConfig.vam.pluginDictionaries = [ { names = [ "vim-trailing-whitespace" ]; } ];
  };

  # system remote plugin manifest should be generated, deoplete should be usable
  # without the user having to do `UpdateRemotePlugins`. To test, launch neovim
  # and do `:call deoplete#enable()`. It will print an error if the remote
  # plugin is not registered.
  test_nvim_with_remote_plugin = neovim.override {
    configure.pathogen.pluginNames = with vimPlugins; [ deoplete-nvim ];
  };
})
