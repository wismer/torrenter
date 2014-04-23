$(document).ready(function() {
  var datas;
  var svg = window.svg = d3.select(document.body).append('svg')

  var wdt = 900

  svg.attr('width', wdt)

  function timer () {
    $.ajax({
      type: "POST",
      url: "/filer",
      dataType: 'json',
      processData: false,
      success: function (data, str, oth) {
        function render () {
          len = data.master_index
          count = 0
          sqr_rt = Math.floor(Math.sqrt(len.length))
          sqr_size = wdt / sqr_rt
          hgt = wdt + sqr_size
          svg.attr('height', hgt)
          svg.selectAll('rect').remove();
          svg.selectAll('rect').data(len).enter().append('rect')
            .attr('x', function(d,i) {
              if (count > sqr_rt - 1) {
                count = 0
              };
              return count++ * sqr_size;
            })
            .attr('y', function(d,i){
              return Math.floor(i / sqr_rt) * sqr_size;
            })
            .attr('stroke', 'black')
            .attr('stroke-width', '1px')
            .attr('fill', function(d,i){
              switch (d) {
                case 'downloaded':
                  return 'red';
                  break;
                case 'free':
                  return 'blue';
                  break;
                case 'downloading':
                  return 'black'
                  break;
                default:
                  return 'green';
              }
            })
            .attr('width', sqr_size)
            .attr('height', sqr_size)



          // download_index = svg.selectAll('rect')

          // download_index.selectAll('rect').data('downloaded').attr('fill', 'red')
          //   .attr('x', function(d,i){ return i * 13;}).attr('y', function(d,i) {return 0;})

          // download_index.selectAll('rect').data('free').attr('fill', 'black')
          //   .attr('x', function(d,i){ return 0;}).attr('y', function(d,i) {return i * 13;})

          // download_index.selectAll('rect').attr('width', 12).attr('height', 12)
        }
        render();
      }
    })
    setTimeout(timer, 5000);
  }
  timer();
})