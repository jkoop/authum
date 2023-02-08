<?php

namespace App\Mail;

use App\Models\PasswordResetToken;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class PasswordReset extends Mailable {
    use Queueable, SerializesModels;

    public string $url;

    /**
     * Create a new message instance.
     *
     * @return void
     */
    public function __construct(public User $user) {
        $resetToken = PasswordResetToken::create([
            'id' => bin2hex(random_bytes(96)),
            'user_id' => $user->id,
        ]);

        $this->url = config('app.url') . '/password-reset/' . $resetToken->id;
    }

    /**
     * Get the message envelope.
     *
     * @return \Illuminate\Mail\Mailables\Envelope
     */
    public function envelope() {
        return new Envelope(
            subject: 'Password Reset',
        );
    }

    /**
     * Build the message.
     *
     * @return $this
     */
    public function build() {
        return $this
            ->subject('Password Reset Link - ' . config('app.name'))
            ->view('emails.password-reset') // html
            ->text('emails.password-reset-text');
    }
}
