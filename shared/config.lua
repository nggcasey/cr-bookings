Config = {}

Config.DebugMode = true --Prints debug messages in the console if true

Config.Permissions = {
    cooldown = 1, --Cooldown time in minutes between making appointments
    maxAppointments = 20, --Max number of active appointments a player can have
}

-- Future Idea: Appointment types saved dynamically in database with additional configurable options and permissions (i.e. cancellation fees, who can cancel etc)
Config.Businesses = {
    ['courts'] = { --Job name as listed in shared/jobs.lua
        label = 'Courts of NSW',
        icon = 'fa-scale-balanced', --use a FontAwesome or other icon
        appointmentTypes = {
            {
                label = 'Short Consult',
                description = 'Consult with a Magistrate or Judge',
                duration = 10, --Minutes
                buffer = 10, --Time after appointment to block out
                fee = 50, --$ amount
            },
            {
                label = 'Long Consult',
                description = 'Consult with Magistrate or Judge about complex matters',
                duration = 20, --Minutes
                buffer = 10, --Time after appointment to block out
                fee = 100, --$ amount
            },
            {
                label = 'Standard Trial',
                description = 'Standard trial (Police/Courts/Lawyers Only)',
                duration = 20, --Minutes
                buffer = 10, --Time after appointment to block out
                fee = 200, --$ amount
                onlyAllowJobs = {
                    {['police'] = 1},
                    {['courts'] = 0},
                    {['redback'] = 1},
                } --only allow players with allowed jobs rank to book this type of appointment
            },
            {
                label = 'Long Trial',
                description = 'Long trial (Police/Courts/Lawyers Only)',
                duration = 30, --Minutes
                buffer = 10, --Time after appointment to block out
                fee = 300, --$ amount
                onlyAllowJobs = {
                    {['police'] = 1},
                    {['courts'] = 0},
                    {['redback'] = 1},
                } --only allow players with allowed jobs rank to book this type of appointment
            },
            {
                label = 'Appeal',
                description = 'Appeal a court result (Police/Courts/Lawyers Only)',
                duration = 20, --Minutes
                buffer = 10, --Time after appointment to block out
                fee = 100, --$ amount
                onlyAllowJobs = {
                    {['police'] = 1},
                    {['courts'] = 0},
                    {['redback'] = 1},
                },
            },
    }},
    ['redback'] = {
        label = 'Redback Legal',
        icon = 'spider',
        appointmentTypes = {
            {
                label = 'Short Consult',
                description = 'Consult with a lawyer',
                duration = 15, --Minutes
                buffer = 10, --Time after appointment to block out
                fee = 50, --$ amount
            },
            {
                label = 'Long Consult',
                description = 'Consult with a lawyer',
                duration = 30, --Minutes
                buffer = 10, --Time after appointment to block out
                fee = 100, --$ amount
            },
        }
    },
    ['nrma'] = {
        label = 'NRMA Mechanics',
        icon = 'car', --use a FontAwesome or other icon
        appointmentTypes = {
            {
                label = 'Job Interview',
                description = 'Book in a job interview',
                duration = 15, --Minutes
                buffer = 10, --Time after appointment to block out
                fee = 0, --$ amount
            },
            {
                label = 'Tuning',
                description = 'Tune your vehicle',
                duration = 30, --Minutes
                buffer = 10, --Time after appointment to block out
                fee = 100, --$ amount
            },
        }
    },
    ['police'] = {
        label = 'NSW Police',
        icon = 'handcuffs', --use a FontAwesome or other icon
        appointmentTypes = {
            {
                label = 'Job Interview',
                description = 'Book in a job interview',
                duration = 15, --Minutes
                buffer = 10, --Time after appointment to block out
                fee = 0, --$ amount
            },
        }
    },
    ['jetstar'] = {
        label = 'Jetstar Aviation',
        icon = 'plane', --use a FontAwesome or other icon
        appointmentTypes = {
            {
                label = 'Job Interview',
                description = 'Book in a job interview',
                duration = 15, --Minutes
                buffer = 10, --Time after appointment to block out
                fee = 0, --$ amount
            },
            {
                label = 'Pilot Exam',
                description = 'Book in a Pilot Exam',
                duration = 30, --Minutes
                buffer = 10, --Time after appointment to block out
                fee = 500, --$ amount
            },
        }
    },
}