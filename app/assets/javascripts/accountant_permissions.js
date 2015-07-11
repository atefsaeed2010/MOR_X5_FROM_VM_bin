  function set_opts(max, arr) {
    for (i=1;i<arr.length;i++){
      for (x=0;x<3;x++) {
        var radio = this.document.getElementById(arr[i]+x);
        if (radio) {
          if (radio.value > max) {
            radio.disabled = true;
            if (radio.checked) {
              var to_move = this.document.getElementById(arr[i]+max);
              if (to_move) {
                to_move.checked = true;
              } else {
                this.document.getElementById(arr[i]+'0').checked = true;
              }
              radio.checked = false;
            }
          } else {
            radio.disabled = false;
          }
        }
      }
    }
  }

