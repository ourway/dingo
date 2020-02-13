<style>
  h1,
  figure,
  p {
    text-align: center;
    margin: 0 auto;
  }

  h1 {
    font-size: 2.8em;
    text-transform: uppercase;
    font-weight: 700;
    margin: 0 0 0.5em 0;
  }

  figure {
    margin: 0 0 1em 0;
  }

  img {
    width: 100%;
    max-width: 400px;
    margin: 0 0 1em 0;
  }

  p {
    margin: 1em;
    direction: ltr;
    text-align: justify;
  }

  @media (min-width: 480px) {
    h1 {
      font-size: 4em;
    }
  }
</style>

<svelte:head>
  <title>Dingo admin console</title>
</svelte:head>

<h1>Dingo Console!</h1>

<figure>
  <img alt="Borat" src="great-success.png" />
  <figcaption>HIGH FIVE!</figcaption>
</figure>

<h2>Quick Help</h2>
<p>
  Each tab above provides related information about related sections, for example: Question Repository tab
  provides required functionalities to add/remove/update or view questions in Dingo repository. Upon clicking
  on the tab, you may require to provide valid credentials. For any technical issues or questions, please call
  Farsheed for more information.
</p>
