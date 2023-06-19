{ config, pkgs, inputs, ... }:

{
  imports = [
    ./dotfiles.nix
  ];
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "qsdrqs";
  home.homeDirectory = "/home/qsdrqs";
  home.packages = with pkgs; [
    htop
    lazygit
  ];

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.05";

  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    initExtraFirst = ''
      if [ -e $HOME/.zshrc ]; then
        ZSH_CUSTOM="$HOME/zsh_custom"
        source $HOME/.zshrc
      fi
    '';
    completionInit = ""; # define in my own zshrc
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName  = "qsdrqs";
    userEmail = "qsdrqs@gmail.com";
    signing.key = "E2D709340CE26E78";
    signing.signByDefault = true;
    extraConfig = {
      core = {
        editor = "$EDITOR";
        pager = "cat";
      };
      credential = {
        helper = "store";
      };
      pull = {
        rebase = true;
      };
    };
  };

  home.file."authorized_keys" = {
    target = ".cache/authorized_keys";
    onChange = ''
      cp ~/.cache/authorized_keys ~/.ssh/
    '';
    text = ''
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDapy0TY1Rg25OQA6StQeiNz6FMync8IOtagynLbWXK1p/bSkDTPTK6HsPtIcZRjBQzhAwSIaDt3PHZMfYUpW+BcGKbvBucm6a1CjsWXzhCo85CmWIIysJh2aUw0dq4cJ12XKmaDzMUtTGjAGleQKueeCiSkkHp+K3j7R18/Ef30nkBXBztVHcbvr6AxoMxVP6MmfAWH39jAauXoNzrxx9cPNGouXytsPyXCTHYN9wY/Qndhi17DknIZJ6qP3DMNl1A3C6Mo7DCsXcfKy4pHPYYal5jM4q6cGWopXGEcTu64NjKr13YXmIgH5syTS8iQlMCIlmaBI/uN2ArNtd180D8feWELBnZze9nePCf4+f1SWLlAncrtYl31/AmMPEsDhpl/itC4E6/wzGcSWLdM3fjuguHtxxaPJkzM2NX31PcMU8lsVGRR/FbErm0ZGFurC2JcIXjwWcZaGCGqJEPWJJkwygAM3XTICJEkvJn+1AVg8DvZncbEupMV0X2muqhPCs=
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCyd6lBQFnZ2Y6sRjsJUY4YPWEqfazVQeZOc2uQcSW/t3sECgz7skDZzcXsUsZ6A2bYeEsuxPgn9WjkWQwNLo7MBTwp0FE7ssnVYKxFsXxI1TkNuOYD86LqxFUtqlj/6+ZJ7gsNHChLMqi7dpL5rmKAt901hpbRfmO07VdX5tXQ4rZWNvDN9cOhLflktzLTApLnrEFiTsQHtpD6OLAktZ3w9wtqVsZsEYUdDpCCR1HFQ4VBJ5ZbR/uWLckVPyQLnw1+PqbIgcFF61Uu65TWMEAOVtrACf0yarVTt68Kv9EDXCu+MpOYJlRxXyYYRNRyG1ShnaxmVaYXY5KE84nA/UeISTgUEGGlSY671CffC1nJyiFQPbnULv/LT0y/AQfpBpkyaQtAAvsZUWF/CSn6jYwMMsseUkv1ShXkvebNhYd0yR3/1Qs47z2upJ3wiy67ZjagDDab9wDhw3os9pKuPR0MKvOW1SVCPfrBFQOSAzo5LCTFDXDIfC4GovHBIQOgQls=
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDEXpXHGctxRmA9Bpv4/9ScFOkxIu7DYx9Lul1gJHAv1nhsn64kowBE5dn0tY3FZNDBVZSiojoeryo6mHyamn28h7Zoql3lQa4+7SkPVKh9VkLMyUsN9X/zMY7Ygv83KhFaT4K3QXbPpXTdoQJxTQiZ+Z2415HoairlfpPZpZmeHcaa8SCL2NfnUN5B1yydO8MzeJz3UL0XRAZ4smByKS/XPeI/0wxlWJPgSG1VmmVSpUFbo4qJVyWNuxWKBITW0juTGvFo5DDUJNSEgsivhlTx5PQZ3BEaW3/brL2La6hAbjxqvfVPiMJvn4Nj1FrhvRGhhydGxYVYI/56gb4TbHKLCLM7gIAez0661scU2LycMxLepRjoLhsGG2ILd1XjQ7MxN303nc4jFPexpHB8xM5zQD6mRRrnGUJkbgQ3ISGNO/VMA3DQ5p90NN7telc91SJss60wB149jkqvifT0DlF8WMx0P+2YNQcVFr73Mx+SZGR4anj2ijKlJCeMG/hWIo8=
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCfAR0FbClPoi7lvz7u5Q/23tfDsfPwKsSulINWYH2DjMU4I69yAPMpRFKAoWerkPNtiyY/ezpZXAPZiAh58+WUFl1c3CvAlBmqfKIpCKQycMXlo7JZuvrUnT+HeKxDWBMmE3BgEZJiKRcyT7Uq/8+03eXbD4pxUjmUwUGPsU1F8CfmaBs2knSaFpClDfZFBJbyeG64NMATzLk9H3z8bIxcMwiQBdPH/6fZgpbUm3YsebmQpS69sWusEI93Ias+NeZ02NEUjmXEWruDhqZhsHaMpQqzDPTfC9xkny1LMZdD8eqhT22eEMxhpOUc2xMq7SdAG4Vy62DhGA1RtyoXiVJ5
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDDcfndqIUj6+BoamZ1x7CidHcFPNBKbA7DPjYkd1Imq0snE9SlYU0Uv74hdHgHTLYt/EH8jzOWYcrWNQ8mPcd2T0l6NONe9gXsFdn3vTPFVuzptwyingzFuEBns3jE6lce+5JmY5g6b48s13uPtqAUjDaa0BhGfU3/B/9phHsoLJ3SIG5Ctzlw4SoibkDC1zWuIIhabMhLVzg47i+v3sfO60/jx/SOJ/fVfMu8Jo7NMdeaoAuvWIj1yfkqIHYaWReksIOCe/HBtMvAu1aLT7FOjysAniVjaRUwzXmK7OE/VYuN+cS8chUvh/5/7lRbEOWt9b6CvE8Rx/JQ4byzgbAZK61KXXJcmGxTj96h95IukmWcQ/6I4J3HIxM8AxfkA09NCR4jQUDJW9HzuTcf0x2nanBNt92KPxdnAQ7tj7cXmgT1aewBQDxCOIWBtEI+/3tp4TmUbP7ckgWnq9+RFtANfVJpdWe5dXuCe56/pPo28oqj9txN3fN010shAWCH2Ck=
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDZSWPq/2miZnnS9cUb7phR+cMhRPrbsaVZJkdMOwpJqIptaQvMqNDinePcdEW86NRTej1DC7iaklLjuRDZKVb09SwXfAPhBjyF0TOv/4yjOHBB56XBPGmk0N10ZXp4gbS4Sz3DcTIwWjHQSQxxSKjdzxd7AyfUsIA45ktEzvgtMlB0caaMGNwbbhWRK7c3nyEvenkUWwANo9uiDEPMbrYwDWz5XxziE9fvb0QVyrNscmQjMdE3m1XcEU+jqHYYYLVhxRZomrDLMXiQcppASXtq6nuR9Zu/X8nxNiPc3Dg5AjokI7Fpg9qjxJUqTkl9RgCD/6pGxDNY0hP7smUVSp/UEvSVXftY4W15YIRD5nq4ZQNJGwa5fOQaYrHtTXA71epJlWFGdgI+iOtVj60Ff4Wi6yQTfD0srtBHXM6TarrmONiYRVMUS73EeFOCd6cgGPB7KHCxb8QefGzjqtbEe4cNwR6SOLDaEPvPOhWWdDBENAeagX4RatykAwRRzzLmxl0=
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCd8e7AXRM2XW//Dzwrg0rmDNMSON/DTYJs7JozQ90sI3/q8fWIwR/F0FqxaotvKybMXxlHgESnoMH07srz2ehyrYV/dCnnhEmFDFKSpXky/hxygmRxuhQeCXu/NHpZ5EwywLL+u2dyiXdmG0e9KIWtPb5aXdMuDTEVnoBpzZ9//6XsMbPBCUPR4FF/r81trzp83+RDzF/yo2Pi3eO0DVfxUQNmXbtDk863R/+7SF+Hf88l1s5QqFBd8QiYHmRP2NuaNTtm4gmcy/0kq62eW0GQ96t4b5SCW7zDgwkYf4yfJEXa6nVawOUHlRLz19zl29WC2UmfCxtUVKtGr9+hATvS2/gyO4Ijl4YB0Cx6PfmDRmxlJREh6i9t3fTfOI3l4sSQhq9kv3qHxdxev3wzu22HwxaQK0cqgVb5QIi094E/IrwYKDcHWmbJyEtgtJFHWlobHjb+48AY+u2UOBD3rRdOvlf1ZZokj2dKsV54wtjaNyhOxKOownAs+m2DJu+0M4M=
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGfEdTcbv926RJSiTggCQP5SKrJBYOkaikioJujoFDf/mOBU5KsxkMqNMM42aVRgaOUi7IajnBQjzb2vHejEUQ+FlKS85AHVnv3BAWbdvab7F8variZpayyrI/2l0Qvt8yuBciu9YtbQhW8gUnY5XyNHUeTfQtya8N6oZy0JPQLYO5N4AhFhoJfkzPzCpFo6Jx2vNFYQpkHnjp5qGwnAnUp4unMvOt+y/1otF5wyRAnhBSB5mMc5UaNKucZQ2ejeyCVstMge5ABetL5nusWLVaUE0goLOtoryyO21T1SItLPM2oZO2Bx8tDS+uvjinPlaMJst3ISSNKHgfKmBvQMxVTpvVmFqTlNIzXgcASlZtIg5PkHlq8VmpSJPf97MUfsPLt+lb1Ex9QGu3O2iZ5ezIjIl4kszFbZme8bh3AWs8++fB5fp3QkwNqDXXSWO+1cb9iB9XvvJTYCF2gZ2yvaeVgHm3EPziulKwu9OFg8UiGIm+Zn3uR7VhQiNxVM9qy1s=
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7DGX6fKYmq20X78b5U/JScS+jdHkMeD7h9nIti7W+Bq5hYc+g99u5n/Bia8aAdzReL4d8aNPSL7iH7Ja/BvFdYsDfKl+vFsB/+Yc/FhF9jHV5L2uW+wL2XfrcYoqRkRcNgd7sFDSkrrKhLYpolZS+IvYyzSZuov1gUex56ijV4ARTb3omx1pz0jrlqv5eMfTvBZnl+D6Y4GV496BBhS/lKc0VMG6zqENkLbNGzerC42BrNux7f4PXjf9699t0UDDQcCfxQUSP52zN1SAE58FdgqGJ7KjhmyOnd/JXGk1WqxOYYokFC+Qn9KHZHy5vfI+6wGzNojMrIReWfuqFT1+Zj3dawTMIof9vU7zHxi0+m1c9ByPh3cNfyniZy/zuoG18h9hwKTvywZfblc0aa4ziUsw6abYtWhh88y/9CMcMtBWMyxQjEJbcLeJtCyopvd5gYTWM1vsBpQqcP2poT8kpjMIJf2T7yLvGFilcMvRl5tmxQXUZcNzFBpFdVV3o1Fc=
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDFIN28Wda9CqbFZ+ZkL8/kbBYBjqkE/NqTCGfbM0WU8tu6t4Y4COTmS8MwZ7M9fNfc+sBY235KiNPD0rs4/tF+igRYBteY/9G6MhJ04k3eQORrrUK0yuYPf+Sb3TuHc4WYtBSubET6fNuLd7UKj662AdSCVOIuKoxopIayAyfMJ+3XYAe373KT7B/LruKjI7h/niaEu7UCZYlNEZReCqz3vNr1gHHk6ww9J3qJkWgdm6A/+MAd7f9Jqr2ffkg5BOAfz/mXh8hhgVcvy9svnsWY+A9DKefAoiMz7TmSzc3q8ofJimYVqj1qVbhso34meIFAPqwhKxzkq16GSZu8VON4Ha+oz3FspmVpu//nILqFtf5x2E+q+Uus9lv+PXlZdY4J9TooTxEd1VX1v7IxdoAypAMUpv1eieCYc3cBoC2GSlBF/A4KZ/NXOjrMhN6bWtUo9FJNfRWrhBL2pIFM6738AGayoRonnBSS5ymEbEqigQTKHm+wH9Ij4lcin2z/SIc=
      ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDkZCdvrA9W2qb2mIDJeaFStS95JbPhvSJ0UmnuwquD4nKTvykHHKJX+KlHjHHGwbUR0y4ICOjhsAs3nn2iqpg5bRDMiJEDPD8DmrBkTMbIBRs8bykCmHT89XPBT6XSkJ6Tw4buylKcMlu5AprCSiuVSWL6fRLMP2Kr+8P8pKJ4JUoZBy8kI1lJUeT/YIrZ80wVZy+MKoxhYKHMcwWq07PL+xdbXJSVCo/fEqXFZM8nZdAYT6l2kZXlW7qPhacCsoI5rXN+Wab6WVhLduvKSV8Jo6yIPk19y+vmEBb2OJ65W6IY9BS70bmCnuPGN/1stYv+eU81TMzixQmwMdP9rxPjxf9EBMeAuOva+Xhi0LcXyvzN9QQy9rm70mwqkZ9EE8EHexTUV1j7DWoQtuEomnKG+J1taH21ibV906flCMgvoUzYbLchFdBK6+Xoz7QtlWbBhcXcbXjzLC27VaKXIzTZYUSxvrCWFrE3eM8+JDshAmaPyHmInF3KSPYQkpFqcoU=
    '';
  };
}
