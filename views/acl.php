<!DOCTYPE html>
<html lang="en-CA">

<head>
    <meta charset="utf-8">
    <meta name=viewport content="width=device-width,initial-scale=1">
    <title>Access-Control List - Authum</title>
    <script>
        function setTheFieldNames() {
            let counter = 0;
            document.querySelectorAll('tbody tr').forEach(tr => {
                tr.querySelectorAll('select, input').forEach(field => {
                    if (field.name != "") {
                        field.name = `${counter}[${field.name}]`;
                    }
                });
                counter++;
            });
        }
    </script>
</head>

<body>
    <h1>Access-Control List</h1>
    <p>
        <a href="/">Home</a>
    </p>

    <p>When a forward auth request is made, the rules in this ACL are compared one-by-one in order from top to bottom. The first rule to match determines the allowed-ness (allow/deny). Paths never begin with a a slash.</p>

    <form method="post" onSubmit="setTheFieldNames()">
        <table>
            <thead>
                <tr>
                    <th colspan="2">Service(s)</th>
                    <th colspan="2">User(s)</th>
                    <th>Method Regex</th>
                    <th>Domain Name Regex</th>
                    <th>Path Regex</th>
                    <th>If Matches</th>
                    <th>Comment</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach (DB::query('SELECT * FROM acl ORDER BY `order`') as $rule) : ?>
                    <tr>
                        <td><select name="service_invert">
                                <option value="0" <?= $rule['service_invert'] ? '' : 'selected' ?>>Is</option>
                                <option value="1" <?= $rule['service_invert'] ? 'selected' : '' ?>>Is not</option>
                            </select></td>
                        <td><select name="service">
                                <option value=""><i>-- any --</i></option>
                                <optgroup label="groups">
                                    <?php view('options-service-group', ['selected' => $rule['service_group_id']]) ?>
                                </optgroup>
                                <optgroup label="services">
                                    <?php view('options-service', ['selected' => $rule['service_id']]) ?>
                                </optgroup>
                            </select></td>
                        <td><select name="user_invert">
                                <option value="0" <?= $rule['user_invert'] ? '' : 'selected' ?>>Is</option>
                                <option value="1" <?= $rule['user_invert'] ? 'selected' : '' ?>>Is not</option>
                            </select></td>
                        <td><select name="user">
                                <option value=""><i>-- any --</i></option>
                                <optgroup label="groups">
                                    <?php view('options-user-group', ['selected' => $rule['user_group_id']]) ?>
                                </optgroup>
                                <optgroup label="users">
                                    <?php view('options-user', ['selected' => $rule['user_id']]) ?>
                                </optgroup>
                            </select></td>
                        <td><input name="method_regex" maxlength="255" value="<?= $rule['method_regex'] ?>" /></td>
                        <td><input name="domain_name_regex" maxlength="255" value="<?= $rule['domain_name_regex'] ?>" /></td>
                        <td><input name="path_regex" maxlength="255" value="<?= $rule['path_regex'] ?>" /></td>
                        <td><select name="if_matches">
                                <option <?= $rule['if_matches'] == 'allow' ? 'selected' : '' ?>>allow</option>
                                <option <?= $rule['if_matches'] == 'deny' ? 'selected' : '' ?>>deny</option>
                            </select></td>
                        <td><input name="comment" maxlength="255" value="<?= $rule['comment'] ?>" /></td>
                    </tr>
                <?php endforeach ?>
                <tr>
                    <td><select disabled>
                            <option value="0">Is</option>
                            <option value="1">Is not</option>
                        </select></td>
                    <td><select disabled>
                            <option selected><i>-- any --</i></option>
                            <optgroup label="groups">
                                <?php view('options-service-group') ?>
                            </optgroup>
                            <optgroup label="services">
                                <?php view('options-service') ?>
                            </optgroup>
                        </select></td>
                    <td><select disabled>
                            <option value="0">Is</option>
                            <option value="1">Is not</option>
                        </select></td>
                    <td><select disabled>
                            <option selected><i>-- any --</i></option>
                            <optgroup label="groups">
                                <?php view('options-user-group') ?>
                            </optgroup>
                            <optgroup label="users">
                                <?php view('options-user') ?>
                            </optgroup>
                        </select></td>
                    <td><input disabled /></td>
                    <td><input disabled /></td>
                    <td><input disabled /></td>
                    <td><select disabled>
                            <option>allow</option>
                            <option selected>deny</option>
                        </select></td>
                    <td><input value="deny all" disabled /></td>
                </tr>
            </tbody>
        </table>
        <button type="submit">Save</button>
    </form>

    <?php view('logged-in-footer') ?>
</body>

</html>
