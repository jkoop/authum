<?php

namespace App\Http\Controllers;

use App\Models\AuthenticationReturnToken;
use App\Models\Service;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Redirect;

final class ForwardAuthController extends Controller {
    private string $method;
    private string $proto;
    private string $host;
    private int $port;
    private string $uri;
    private string $path;
    private array $query;
    private Service $service;

    public function __construct(Request $request) {
        $this->method = $request->header("x-forwarded-method") ?? abort(400);
        $this->proto = $request->header("x-forwarded-proto") ?? abort(400);
        $this->host = $request->header("x-forwarded-host") ?? abort(400);
        $this->port = $request->header("x-forwarded-port") ?? abort(400);

        $uri = $request->header("x-forwarded-uri") ?? abort(400);
        $this->uri = $uri;

        $this->path = ltrim(strtok($uri, "?"), "/");

        $query = strtok("?") ?? "";
        $this->query = [];
        parse_str($query, $this->query);

        $this->service = Service::whereHas('domainNames', function ($query) {
            $query->where('domain_name', $this->host);
        })->first() ?? abort(400);
    }

    public function handle(Request $request) {
        if ($this->path == $this->service->logout_path) {
            return redirect(config('app.url') . '/logout');
        }

        if ($this->path == '_authum/from-login') {
            if (Auth::check()) {
                return redirect("{$this->proto}://{$this->host}:{$this->port}/"); // root of requested site
            } else {
                return $this->attemptLogin($request);
            }
        }

        if (Auth::check()) {
            if ($this->isUserPermitted()) {
                return response("OK");
            } else {
                abort(403);
            }
        } else {
            return redirect(config('app.url') . '/login?' . http_build_query([
                'from' => "{$this->proto}://{$this->host}:{$this->port}/" . ltrim($this->uri, "/"), // includes query string
            ]));
        }
    }

    private function attemptLogin() {
        AuthenticationReturnToken::where('expires_at', '<', now()->timestamp)->delete();

        $token = AuthenticationReturnToken::find($this->query['token'] ?? "");
        if (!$token) {
            return response(view('pages.token.bad'), 400);
        }

        $token->delete();
        setcookie('session_id', $token->parent_session_id, strtotime("+30 days"), "/", $this->host, true, true);
        return Redirect::to($token->forward_to);
    }

    /**
     * @return true|never `true` if permitted, `false` if not
     */
    private function isUserPermitted(): bool {
        return true;
    }
}
