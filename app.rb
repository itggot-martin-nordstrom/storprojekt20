require "sinatra"
require "slim"
require "bcrypt"
require "SQLite3"

enable :sessions

db = SQLite3::Database.new('database/database.db')
db.results_as_hash = true

get('/') do
    slim(:start)
end

post('/sign_up') do
    username = params["username"]
    password = params["password"]
    confirm_password = params["c_password"]

    result = db.execute("SELECT id FROM users WHERE username=?", username)

    if result.empty?
        if password == confirm_password
            if password.length >= 4
                password_digest = BCrypt::Password.create(password)
                db.execute('INSERT INTO users(username, password_digest) VALUES (?,?)', [username, password_digest])
                session[:id] = db.execute('SELECT id FROM users WHERE username=?', username)[0]['id']
                redirect('users/first_login')
            else
                session[:error] = "Password is too short"
                redirect('/error')
            end
        end
        session[:error] = "Passwords don't match"
        redirect('/error')
    else
        session[:error] = "User already exists"
        redirect('/error')
    end
end

get('/users/first_login') do 
    slim(:"users/first_login")
end

post('/users/complete_profile') do 
    firstname = params["new_name"].downcase
    class_name = params["class"].downcase

    p session[:id]

    db.execute("UPDATE users SET name=?, class_name=? WHERE id=?", [firstname, class_name, session[:id]])
    # ???
    redirect('/users/home')
end

post("/login") do
    username = params["username"]
    password = params["password"]

    result = db.execute("SELECT id, password_digest FROM users WHERE username = ?", username)
    if result.empty?    
        session[:error] = "Invalid credentials"
        redirect('/error')
    else
        user_id = result.first["id"]
        password_digest = result.first["password_digest"]
        if BCrypt::Password.new(password_digest) == password
            session[:id] = user_id
            # p session[:id]
            redirect("/users/home")
        else
            session[:error] = "Wrong password"
            redirect('/error')
        end
    end
end

post('/users/logout') do
    session[:id] = nil
    redirect('/')
end

get('/users/home') do
    if session[:id] == nil
        session[:error] = "Not logged in"
        redirect('/error')
    else
        # p session[:id]
        current_user = session[:id]
        
        current_class = db.execute('SELECT class_name FROM users WHERE id=?', current_user)
        # p current_class
        
        if current_class[0]['class_name'] != nil
            
            classmates = db.execute('SELECT id, name FROM users WHERE class_name=? AND id !=?', [current_class[0]['class_name'], current_user])
            slim(:"users/home", locals:{classmates: classmates})
        else
            # votes = db.execute('SELECT * FROM users LEFT JOIN options ON users.id = options.for_user WHERE class_name=? AND for_user !=?', [current_class.to_s, current_user])
            votes = db.execute('SELECT name, class_name, content, no_of_votes FROM users LEFT JOIN options ON users.id = options.for_user WHERE option_id IS NOT NULL ORDER BY no_of_votes')
            slim(:"users/admin", locals:{options: votes})
        end
    end
end

get('/users/voting/:id') do
    id = params["id"]
    current_user = session[:id]

    # safety för användare som inte är i samma klass
    user_classname = db.execute('SELECT class_name FROM users WHERE id=?', current_user)
    target_classname = db.execute('SELECT class_name FROM users WHERE id=?', id)
    p user_classname
    p target_classname
    if user_classname != target_classname
        session[:error] = "Oops, you can't vote for that user!"
        redirect('/error')
    else
        options = db.execute('SELECT option_id, content, no_of_votes FROM options WHERE for_user = ? ORDER BY no_of_votes', id)
        users_vote = db.execute("SELECT content FROM options WHERE option_id = (SELECT option_id FROM votes WHERE voter_id = ? AND option_target_id = ?)", [current_user, id])
        # p users_vote
        if users_vote != []
            users_vote = users_vote.first['content']
        end

        slim(:"users/voting", locals:{votes: options, vote_for: id, users_vote: users_vote})
    end

end

post('/vote/new/:option_for') do
    content = params['new_option']
    option_for = params['option_for']
    
    # safety för dubletter
    exister = db.execute('SELECT option_id FROM options WHERE content=? AND for_user=?', [content, option_for])

    if exister.empty?
        db.execute('INSERT INTO options(content, for_user) VALUES (?,?)', [content, option_for])
        redirect("/users/voting/#{option_for}")
    else
        session[:error] = "Option already exists, go vote for it!"
        redirect('/error')
    end

    # option_id = db.execute('SELECT option_id FROM options WHERE content=? AND for_user=?', [content, option_for])[0]['option_id'] 
end

post('/vote/:vote_for/:option_id') do
    current_user = session[:id]
    option_id = params['option_id']
    vote_for = params['vote_for']

    exister = db.execute('SELECT option_id FROM votes WHERE voter_id=? AND  option_target_id=?', [current_user, vote_for])
    
    if exister.length != 0
        db.execute('DELETE FROM votes WHERE voter_id=? AND  option_target_id=?', [current_user, vote_for])
    end
    db.execute('INSERT INTO votes(voter_id, option_target_id, option_id) VALUES (?,?,?)', [current_user, vote_for, option_id])

    redirect("/users/voting/#{vote_for}")
end

get('/error') do
    slim(:error, locals:{error_message: session[:error]})
end