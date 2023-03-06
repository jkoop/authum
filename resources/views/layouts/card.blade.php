@extends('layouts.html')
@section('actual-content')
    <style>
        #cardContainer {
            position: absolute;
            left: 0;
            top: 0;
            width: 100%;
            min-height: 100%;
            display: flex;
            padding: 0.5rem;
            justify-content: space-around;
            align-items: flex-start;
            box-sizing: border-box;
            backdrop-filter: blur(0.5rem);
            background-color: #0008;
        }

        #backdrop {
            position: fixed;
            left: 0;
            top: 0;
            width: 100%;
            height: 100%;
            overflow: hidden;
        }

        #content {
            padding: 0;
            background-color: white;
            width: fit-content;
            max-width: calc(100vw - 3rem);
        }

        #content>div {
            padding: 1rem;
        }

        #content>*:nth-child(1) {
            margin-top: 0;
            min-width: 250px;
        }

        @media screen and (min-width: 600px) {
            #cardContainer {
                padding: 0;
                align-items: center;
            }

            #content {
                max-width: calc(100vw - 3rem);
            }
        }
    </style>

    <iframe id="backdrop" src="/dashboard/fake"
        style="border: none; position: absolute; left: 0; top: 0; width: 100%; height: 100%; overflow: hidden;"></iframe>

    <div id="cardContainer">
        <div id="content">
            <div>
                <h1 class="mt-4">@yield('title')</h1>

                @include('blocks.messages')

                @yield('content')
            </div>

            @auth
                <footer>
                    {{ __('Logged in as :userName', ['userName' => Auth::user()?->name ?? 'nobody']) }}
                    <a href="/logout" style="float:right">{{ __('Logout') }}</a>
                </footer>
            @endauth
        </div>
    </div>
@endsection
