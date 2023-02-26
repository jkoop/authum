<?php

namespace App\Mail;

use App\Helpers\Crockford32;
use App\Models\EmailVerifyToken;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Str;

class VerifyEmail extends Mailable {
    use Queueable, SerializesModels;

    public string $url;

    /**
     * Create a new message instance.
     *
     * @return void
     */
    public function __construct(string $email, public User $user) {
        $resetToken = EmailVerifyToken::create([
            'id' => strtolower(Str::ulid() . Crockford32::encode(random_bytes(10))),
            'email_address' => $email,
            'user_id' => $user->id,
            'expires_at' => now()->addMinutes(10)->timestamp,
        ]);

        $this->url = config('app.url') . '/add-email/' . $resetToken->id;
    }

    /**
     * Get the message envelope.
     *
     * @return \Illuminate\Mail\Mailables\Envelope
     */
    public function envelope() {
        return new Envelope(
            subject: 'Verify Email',
        );
    }

    /**
     * Build the message.
     *
     * @return $this
     */
    public function build() {
        return $this
            ->subject('Verify Email - ' . config('app.name'))
            ->view('emails.verify-email') // html
            ->text('emails.verify-email-text');
    }
}
