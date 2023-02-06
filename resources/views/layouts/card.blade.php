@extends('layouts.html')
@section('actual-content')
    <style>
        body {
            display: flex;
            margin: 0.5rem;
            background-color: grey;
            justify-content: space-around;
            align-items: flex-start;
        }

        #content {
            padding: 1rem;
            background-color: white;
            width: fit-content;
            max-width: calc(100vw - 3rem);
        }

        #content>*:nth-child(1) {
            margin-top: 0;
            min-width: 250px;
        }

        @media screen and (min-width: 600px) {
            body {
                height: 100vh;
                margin: 0;
                align-items: center;
            }

            #content {
                max-width: calc(100vw - 3rem);
            }
        }
    </style>

    <div id="content">
        <h1>@yield('title')</h1>

        @include('blocks.messages')

        @yield('content')

        @auth
            <hr>
            <footer>
                Logged in as {{ Auth::user()->name }}
                <a href="/logout" style="float:right">Logout</a>
            </footer>
        @endauth
    </div>
@endsection
