<script>
  export let segment;
  // How auth should work in dingo admin?

  // - In this section, I we'll check for `auth_session_token` and
  // `auth_session_expiration` variables in local storage. If no such
  // varialbe is available, login will be shown in top navbar.

  // - If there are related auth variables in local storage, we should check
  // for following circumstances:
  //    - If `auth_session_expiration` date has been expired, then we should delete all auth
  //    related variables and start again
  //    - If date is still valid, we need to show logout and check for `auth_session_token` validity
  //    using an async api. When the fetch promise is resolved, we then should decide whether to delete
  //    auth variables from local storage or keep them.

  // - Since navbar module is central auth core, we should propagate the information using an store.
  // This store variable should be up to date and every critical module should subscribe to it.



</script>

<style>
  nav {
    border-bottom: 1px solid rgba(255, 62, 0, 0.1);
    font-weight: 300;
    padding: 0 1em;
  }

  ul {
    margin: 0;
    padding: 0;
  }

  /* clearfix */
  ul::after {
    content: "";
    display: block;
    clear: both;
  }

  li {
    display: block;
    float: left;
  }

  li.right {
    display: block;
    float: right;
  }
  .selected {
    position: relative;
    display: inline-block;
  }

  .selected::after {
    position: absolute;
    content: "";
    width: calc(100% - 1em);
    height: 2px;
    background-color: rgb(255, 62, 0);
    display: block;
    bottom: -1px;
  }

  a {
    text-decoration: none;
    padding: 1em 0.5em;
    display: block;
  }
</style>

<nav>
  <ul>
    <li>
      <a class:selected={segment === undefined} href=".">home</a>
    </li>
    <li>
      <a class:selected={segment === 'users'} href="about">Users & Permissions</a>
    </li>


    <li class="right"> <a class:selected={segment === 'logout'} href="logout">logout</a> </li>
    <li class="right"> <a class:selected={segment === 'login'} href="login">Login</a> </li>

  </ul>
</nav>
