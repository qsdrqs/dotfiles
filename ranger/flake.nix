{
  description = "ranger themes and plugins";
  inputs = {
    ranger = {
      url = "github:ranger/ranger";
      flake = false;
    };
    colorschemes = {
      url = "github:qsdrqs/colorschemes";
      flake = false;
    };
    ranger-fzf-marks = {
      url = "github:laggardkernel/ranger-fzf-marks";
      flake = false;
    };
    ranger-archives = {
      url = "github:maximtrp/ranger-archives";
      flake = false;
    };
    ranger-zjumper = {
      url = "github:ask1234560/ranger-zjumper";
      flake = false;
    };
    ranger_devicons = {
      url = "github:alexanderjeurissen/ranger_devicons";
      flake = false;
    };
  };
  outputs = { self, ... }@inputs: {
    inputs = inputs;
    ranger = inputs.ranger;
    colorschemes = inputs.colorschemes;
    plugins = [ "ranger-fzf-marks" "ranger-archives" "ranger-zjumper" "ranger_devicons" ];
  };
}
