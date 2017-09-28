$(function() {

  $("form.delete").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();

    var ok = confirm("Are you sure you want to delete this? This cannot be undone!");
    if (ok) {
      this.submit();
    }
  });

});